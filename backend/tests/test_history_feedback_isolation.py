"""Tests verifying JWT-enforced per-user data isolation, history search/filter/pagination,
preserved diagnosis snapshots, and duplicate-preventing feedback updates.
"""

from __future__ import annotations

import json
from datetime import datetime, timedelta, timezone
from pathlib import Path

from fastapi.testclient import TestClient
from sqlalchemy import func, select

from app.db_models import DiagnosisORM, FeedbackORM
from app.main import create_app


def _register_user(client: TestClient, name: str, email: str) -> tuple[str, dict[str, str]]:
    resp = client.post(
        "/api/v1/auth/register",
        json={
            "full_name": name,
            "email": email,
            "password": "StrongPassword!1",
            "accepted_terms": True,
        },
    )
    assert resp.status_code == 201
    body = resp.json()
    return body["user"]["id"], {"Authorization": f"Bearer {body['access_token']}"}


def _seed_diagnosis(
    app,
    *,
    user_id: str,
    diagnosis_id: str,
    report_id: str,
    device_name: str,
    device_category: str,
    predicted_fault: str,
    severity: str,
    created_at: datetime,
) -> None:
    with app.state.session_factory() as db:
        db.add(
            DiagnosisORM(
                id=diagnosis_id,
                report_id=report_id,
                user_id=user_id,
                device_category=device_category,
                device_name=device_name,
                device_details_json=json.dumps({"name": device_name, "category": device_category}),
                reported_symptoms_json=json.dumps(["Reported symptom"]),
                predicted_fault=predicted_fault,
                severity=severity,
                severity_rationale="Rule-based severity evaluation.",
                model_version="1.0.0",
                created_at=created_at,
            )
        )
        db.commit()


def test_history_enforces_user_isolation_filtering_sorting_and_pagination(tmp_path: Path):
    app = create_app(
        artifact_path=tmp_path / "missing.joblib",
        metadata_path=tmp_path / "missing.json",
        database_url=f"sqlite:///{(tmp_path / 'test.db').as_posix()}",
    )
    client = TestClient(app)

    alice_id, alice_headers = _register_user(client, "Alice Verma", "alice@fixwise.io")
    bob_id, bob_headers = _register_user(client, "Bob Nair", "bob@fixwise.io")

    t1 = datetime(2026, 5, 1, 10, 0, tzinfo=timezone.utc)
    t2 = t1 + timedelta(hours=2)
    _seed_diagnosis(
        app,
        user_id=alice_id,
        diagnosis_id="diag_a1",
        report_id="rep_a1",
        device_name="Samsung S23",
        device_category="smartphone",
        predicted_fault="Battery Degradation",
        severity="high",
        created_at=t1,
    )
    _seed_diagnosis(
        app,
        user_id=alice_id,
        diagnosis_id="diag_a2",
        report_id="rep_a2",
        device_name="Daikin Split AC",
        device_category="air_conditioner",
        predicted_fault="Airflow Restriction",
        severity="low",
        created_at=t2,
    )
    _seed_diagnosis(
        app,
        user_id=bob_id,
        diagnosis_id="diag_b1",
        report_id="rep_b1",
        device_name="Bob Laptop",
        device_category="laptop",
        predicted_fault="Thermal Fault",
        severity="high",
        created_at=t2,
    )

    # Unauthenticated request is rejected (even if spoofed X-User-Id is sent!)
    assert client.get("/api/v1/history").status_code == 401
    assert client.get("/api/v1/history", headers={"X-User-Id": alice_id}).status_code == 401

    # Alice only sees her own 2 records (never Bob's)
    alice_resp = client.get("/api/v1/history", headers=alice_headers)
    assert alice_resp.status_code == 200
    alice_data = alice_resp.json()
    assert alice_data["total"] == 2
    assert {item["report_id"] for item in alice_data["items"]} == {"rep_a1", "rep_a2"}

    # Alice cannot fetch Bob's diagnosis detail snapshot
    cross_access = client.get("/api/v1/history/rep_b1", headers=alice_headers)
    assert cross_access.status_code == 404

    # Bob cannot submit feedback on Alice's diagnosis
    cross_fb = client.post(
        "/api/v1/feedback",
        headers=bob_headers,
        json={
            "diagnosis_id": "diag_a1",
            "report_id": "rep_a1",
            "diagnosis_relevance": "no",
            "resolution_status": "not_resolved",
        },
    )
    assert cross_fb.status_code == 404

    # Alice can fetch her preserved snapshot
    own_detail = client.get("/api/v1/history/rep_a1", headers=alice_headers)
    assert own_detail.status_code == 200
    assert own_detail.json()["diagnosis"]["diagnosis_id"] == "diag_a1"

    # Severity filter + pagination works on real stored records
    paged = client.get("/api/v1/history?page=1&page_size=1&sort=oldest", headers=alice_headers)
    assert paged.status_code == 200
    paged_body = paged.json()
    assert len(paged_body["items"]) == 1
    assert paged_body["has_more"] is True
    assert paged_body["items"][0]["report_id"] == "rep_a1"

    filtered = client.get(
        "/api/v1/history?severity=high&search=battery",
        headers=alice_headers,
    )
    assert filtered.status_code == 200
    assert filtered.json()["total"] == 1
    assert filtered.json()["items"][0]["report_id"] == "rep_a1"


def test_feedback_prevents_duplicates_and_allows_controlled_updates(tmp_path: Path):
    app = create_app(
        artifact_path=tmp_path / "missing.joblib",
        metadata_path=tmp_path / "missing.json",
        database_url=f"sqlite:///{(tmp_path / 'test.db').as_posix()}",
    )
    client = TestClient(app)
    alice_id, headers = _register_user(client, "Alice Verma", "alice2@fixwise.io")

    _seed_diagnosis(
        app,
        user_id=alice_id,
        diagnosis_id="diag_a1",
        report_id="rep_a1",
        device_name="Samsung S23",
        device_category="smartphone",
        predicted_fault="Battery Degradation",
        severity="high",
        created_at=datetime.now(timezone.utc),
    )

    first = client.post(
        "/api/v1/feedback",
        headers=headers,
        json={
            "diagnosis_id": "diag_a1",
            "report_id": "rep_a1",
            "diagnosis_relevance": "partially",
            "resolution_status": "not_attempted",
            "comments": "Will test tomorrow.",
        },
    )
    assert first.status_code == 201

    second = client.put(
        "/api/v1/feedback",
        headers=headers,
        json={
            "diagnosis_id": "diag_a1",
            "report_id": "rep_a1",
            "diagnosis_relevance": "yes",
            "resolution_status": "resolved",
            "comments": "Replaced charger cable and issue resolved.",
        },
    )
    assert second.status_code == 200
    assert second.json()["status"] == "updated"

    with app.state.session_factory() as db:
        assert db.scalar(select(func.count(FeedbackORM.id))) == 1
