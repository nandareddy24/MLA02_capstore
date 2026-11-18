"""Pytest suite verifying the FixWise diagnosis API contract, JWT authentication,
validation, model-pending behavior, preprocessing parity, rule-based severity,
uncertainty handling, duplicate-report protection, and SQLAlchemy persistence.
"""

from __future__ import annotations

import json
from pathlib import Path

import joblib
import pandas as pd
from fastapi.testclient import TestClient
from sklearn.ensemble import RandomForestClassifier
from sklearn.pipeline import Pipeline
from sqlalchemy import func, select

from app.db_models import DiagnosisORM, RecommendationORM
from app.main import create_app
from app.preprocessing import build_preprocessor, extract_error_code_prefix, symptom_column_name


def _register_and_auth(client: TestClient, email: str = "tech@fixwise.io") -> dict[str, str]:
    resp = client.post(
        "/api/v1/auth/register",
        json={
            "full_name": "Test Technician",
            "email": email,
            "password": "StrongPassword!1",
            "accepted_terms": True,
        },
    )
    assert resp.status_code == 201
    token = resp.json()["access_token"]
    return {"Authorization": f"Bearer {token}"}


def _sample_payload(**overrides) -> dict:
    base = {
        "report_id": "rep_test_001",
        "device": {
            "id": "cat_smartphone",
            "name": "Samsung Galaxy S23 (Smartphone)",
            "category": "smartphone",
            "manufacturer": "Samsung",
            "model_name": "Galaxy S23",
            "age": "2–4 years",
            "operating_environment": "Indoor – Normal",
        },
        "symptoms": [
            "Rapid battery drain",
            "Overheating during normal use",
        ],
        "error_code": "BAT-02",
        "started_when": "Within the last week",
        "operating_conditions": "Occurs during standard charging",
        "description": "Device becomes warm and drops from 80% to 20% rapidly.",
    }
    base.update(overrides)
    return base


def test_health_and_analyze_report_model_integration_pending_when_artifact_missing(tmp_path: Path):
    app = create_app(
        artifact_path=tmp_path / "missing.joblib",
        metadata_path=tmp_path / "missing.json",
        database_url=f"sqlite:///{(tmp_path / 'test.db').as_posix()}",
    )
    client = TestClient(app)

    health_resp = client.get("/api/v1/health")
    assert health_resp.status_code == 200
    health = health_resp.json()
    assert health["model_loaded"] is False
    assert health["integration_status"] == "pending"

    # Unauthenticated call must be rejected with 401
    unauth_resp = client.post("/api/v1/diagnosis/analyze", json=_sample_payload())
    assert unauth_resp.status_code == 401

    headers = _register_and_auth(client)
    analyze_resp = client.post(
        "/api/v1/diagnosis/analyze",
        json=_sample_payload(),
        headers=headers,
    )
    assert analyze_resp.status_code == 503
    body = analyze_resp.json()
    assert body["code"] == "MODEL_INTEGRATION_PENDING"


def test_analyze_rejects_invalid_payload_with_422(tmp_path: Path):
    app = create_app(
        artifact_path=tmp_path / "missing.joblib",
        metadata_path=tmp_path / "missing.json",
        database_url=f"sqlite:///{(tmp_path / 'test.db').as_posix()}",
    )
    client = TestClient(app)
    headers = _register_and_auth(client)

    resp = client.post(
        "/api/v1/diagnosis/analyze",
        json=_sample_payload(symptoms=[]),
        headers=headers,
    )
    assert resp.status_code == 422
    assert resp.json()["code"] == "VALIDATION_ERROR"


def test_analyze_contract_with_verified_sklearn_fixture(tmp_path: Path):
    """Tests the full preprocessing -> RandomForestClassifier -> severity rules ->
    evidence -> uncertainty -> SQLAlchemy persistence + duplicate protection.
    """
    known_symptoms = [
        "Rapid battery drain",
        "Overheating during normal use",
        "Battery swelling or back cover lift",
        "Screen flickering or lines",
    ]
    rows = []
    labels = []
    fixture_cases = [
        (["Rapid battery drain", "Overheating during normal use"], "BAT-02", "Battery Degradation"),
        (["Rapid battery drain", "Battery swelling or back cover lift"], "BAT-09", "Battery Degradation"),
        (["Overheating during normal use"], "THM-01", "Thermal Management Fault"),
        (["Screen flickering or lines"], "DSP-04", "Display Panel or Flex Cable Fault"),
    ] * 4

    for syms, code, label in fixture_cases:
        row = {
            "device_category": "smartphone",
            "manufacturer": "Samsung",
            "device_age": "2–4 years",
            "operating_environment": "Indoor – Normal",
            "started_when": "Within the last week",
            "error_code_prefix": extract_error_code_prefix(code),
            "symptom_count": float(len(syms)),
            "has_error_code": 1.0,
        }
        for known in known_symptoms:
            row[symptom_column_name(known)] = 1.0 if known in syms else 0.0
        rows.append(row)
        labels.append(label)

    pipeline = Pipeline(
        steps=[
            ("preprocess", build_preprocessor(known_symptoms)),
            ("classifier", RandomForestClassifier(n_estimators=25, random_state=42)),
        ]
    )
    pipeline.fit(pd.DataFrame(rows), labels)

    artifact_path = tmp_path / "test_model.joblib"
    metadata_path = tmp_path / "test_metadata.json"
    joblib.dump(pipeline, artifact_path)
    metadata_path.write_text(
        json.dumps(
            {
                "model_version": "test-fixture-1.0",
                "algorithm": "RandomForestClassifier",
                "is_calibrated": True,
                "evaluated_on_held_out_test": True,
                "known_symptoms": known_symptoms,
            }
        ),
        encoding="utf-8",
    )

    app = create_app(
        artifact_path=artifact_path,
        metadata_path=metadata_path,
        database_url=f"sqlite:///{(tmp_path / 'test.db').as_posix()}",
    )
    client = TestClient(app)
    headers = _register_and_auth(client)

    resp = client.post("/api/v1/diagnosis/analyze", json=_sample_payload(), headers=headers)
    assert resp.status_code == 200
    data = resp.json()

    assert data["diagnosis_id"].startswith("diag_")
    assert data["report_id"] == "rep_test_001"
    assert data["predicted_fault_category"] == "Battery Degradation"
    assert data["confidence_is_calibrated"] is True
    assert 0.0 <= data["confidence"] <= 1.0
    assert data["severity"] == "high"
    assert len(data["evidence"]) >= 3
    assert data["model_version"] == "test-fixture-1.0"
    assert data["processing_time_ms"] >= 0
    assert "not a confirmed physical fault" in data["uncertainty"]["disclaimer"]

    # Re-submitting the exact same report_id returns preserved diagnosis without duplicating!
    dup_resp = client.post("/api/v1/diagnosis/analyze", json=_sample_payload(), headers=headers)
    assert dup_resp.status_code == 200
    assert dup_resp.json()["diagnosis_id"] == data["diagnosis_id"]

    # Test critical safety rule escalation (battery swelling -> critical severity)
    critical_resp = client.post(
        "/api/v1/diagnosis/analyze",
        json=_sample_payload(
            report_id="rep_test_002",
            symptoms=["Battery swelling or back cover lift"],
        ),
        headers=headers,
    )
    assert critical_resp.status_code == 200
    assert critical_resp.json()["severity"] == "critical"

    # Saved recommendations endpoint returns persisted plan
    rec_resp = client.get("/api/v1/diagnosis/rep_test_001/recommendations", headers=headers)
    assert rec_resp.status_code == 200
    assert rec_resp.json()["report_id"] == "rep_test_001"

    with app.state.session_factory() as db:
        diag_count = db.scalar(select(func.count(DiagnosisORM.id)))
        rec_count = db.scalar(select(func.count(RecommendationORM.id)))
        assert diag_count == 2
        assert rec_count >= 2
