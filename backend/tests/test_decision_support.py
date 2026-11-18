"""Tests for the separate Decision Support Service, reviewed Knowledge Base,
severity safety rules, dangerous fault handling, Bayesian non-fabrication, and feedback.
"""

from __future__ import annotations

import json
from pathlib import Path

import pytest
from fastapi.testclient import TestClient
from sqlalchemy import func, select

from app.config import BACKEND_ROOT
from app.db_models import DiagnosisORM, FeedbackORM, UserORM
from app.knowledge_base import FaultKnowledgeBase
from app.main import create_app
from app.probabilistic_decision import (
    ProbabilisticInputsUnavailableError,
    compute_bayesian_posterior,
)
from app.severity_rules import SeverityRuleEngine

DEFAULT_SEVERITY_RULES_PATH = BACKEND_ROOT / "data" / "severity_rules.json"


def _register_and_auth(client: TestClient, email: str = "ds@fixwise.io") -> tuple[str, dict[str, str]]:
    resp = client.post(
        "/api/v1/auth/register",
        json={
            "full_name": "Decision Support Tester",
            "email": email,
            "password": "StrongPassword!1",
            "accepted_terms": True,
        },
    )
    assert resp.status_code == 201
    body = resp.json()
    return body["user"]["id"], {"Authorization": f"Bearer {body['access_token']}"}


def test_safe_fault_returns_ranked_reviewed_steps_with_checkable_initial_check(tmp_path: Path):
    app = create_app(
        artifact_path=tmp_path / "missing.joblib",
        metadata_path=tmp_path / "missing.json",
        database_url=f"sqlite:///{(tmp_path / 'test.db').as_posix()}",
    )
    client = TestClient(app)
    _, headers = _register_and_auth(client)

    resp = client.post(
        "/api/v1/decision-support/recommend",
        headers=headers,
        json={
            "diagnosis_id": "diag_ac_01",
            "report_id": "rep_ac_01",
            "device_category": "air_conditioner",
            "device_name": "Daikin Split AC",
            "predicted_fault": "Airflow Restriction or Low Cooling Efficiency",
            "symptoms": ["Blowing warm or room-temperature air", "Weak airflow from indoor vents"],
        },
    )
    assert resp.status_code == 200
    plan = resp.json()
    assert plan["severity"] == "safe"
    assert plan["is_dangerous_fault"] is False
    assert plan["expert_review_status"] == "reviewed"
    assert plan["first_recommended_check"]["risk_level"] == "safe"
    assert plan["first_recommended_check"]["is_checkable"] is True
    risk_sequence = [step["risk_level"] for step in plan["recommendations"]]
    assert risk_sequence[0] == "safe"
    assert risk_sequence[-1] == "caution"


def test_dangerous_fault_triggers_safety_banner_and_disables_diy_checkboxes(tmp_path: Path):
    app = create_app(
        artifact_path=tmp_path / "missing.joblib",
        metadata_path=tmp_path / "missing.json",
        database_url=f"sqlite:///{(tmp_path / 'test.db').as_posix()}",
    )
    client = TestClient(app)
    _, headers = _register_and_auth(client)

    resp = client.post(
        "/api/v1/decision-support/recommend",
        headers=headers,
        json={
            "diagnosis_id": "diag_sp_99",
            "report_id": "rep_sp_99",
            "device_category": "smartphone",
            "device_name": "Smartphone",
            "predicted_fault": "Battery Degradation",
            "symptoms": ["Battery swelling or back cover lift"],
        },
    )
    assert resp.status_code == 200
    plan = resp.json()
    assert plan["severity"] == "high"
    assert plan["is_dangerous_fault"] is True
    assert plan["immediate_safety_banner"] is not None
    assert plan["escalation"]["stop_using_device"] is True
    assert plan["escalation"]["requires_technician"] is True
    assert all(step["is_checkable"] is False for step in plan["recommendations"])


def test_unreviewed_or_unsafe_kb_records_are_blocked(tmp_path: Path):
    severity_engine = SeverityRuleEngine(DEFAULT_SEVERITY_RULES_PATH)

    kb_draft = tmp_path / "kb_draft.json"
    kb_draft.write_text(
        json.dumps(
            {
                "records": [
                    {
                        "id": "draft_rec",
                        "device_category": "laptop",
                        "fault_category": "Unreviewed Fault",
                        "related_symptoms": ["No power"],
                        "possible_causes": ["Draft"],
                        "severity": "safe",
                        "safety_warnings": [],
                        "recommended_initial_checks": [],
                        "troubleshooting_steps": [],
                        "escalation_requirements": "Tech",
                        "expert_review_status": "draft",
                    }
                ]
            }
        ),
        encoding="utf-8",
    )
    kb = FaultKnowledgeBase(kb_draft, severity_engine)
    assert kb.reviewed_records == []

    kb_unsafe = tmp_path / "kb_unsafe.json"
    kb_unsafe.write_text(
        json.dumps(
            {
                "records": [
                    {
                        "id": "unsafe_rec",
                        "device_category": "air_conditioner",
                        "fault_category": "Electrical Fault",
                        "related_symptoms": ["No power"],
                        "possible_causes": ["Short"],
                        "severity": "high",
                        "safety_warnings": [],
                        "recommended_initial_checks": [],
                        "troubleshooting_steps": [
                            {
                                "id": "bad_step",
                                "title": "Inspect wiring",
                                "instructions": "Open electrical panel and handle live wiring.",
                                "risk_level": "safe",
                                "is_checkable": True,
                            }
                        ],
                        "escalation_requirements": "Tech",
                        "expert_review_status": "reviewed",
                    }
                ]
            }
        ),
        encoding="utf-8",
    )
    with pytest.raises(ValueError, match="safety guardrail"):
        FaultKnowledgeBase(kb_unsafe, severity_engine)


def test_bayesian_module_refuses_invented_priors():
    with pytest.raises(ProbabilisticInputsUnavailableError):
        compute_bayesian_posterior(
            observed_evidence=["Overheating"],
            priors=None,
        )


def test_feedback_endpoint_saves_against_owned_diagnosis_id(tmp_path: Path):
    app = create_app(
        artifact_path=tmp_path / "missing.joblib",
        metadata_path=tmp_path / "missing.json",
        database_url=f"sqlite:///{(tmp_path / 'test.db').as_posix()}",
    )
    client = TestClient(app)
    user_id, headers = _register_and_auth(client)

    with app.state.session_factory() as db:
        db.add(
            DiagnosisORM(
                id="diag_ac_01",
                report_id="rep_ac_01",
                user_id=user_id,
                device_category="air_conditioner",
                device_name="Daikin Split AC",
                device_details_json=json.dumps({"name": "Daikin Split AC", "category": "air_conditioner"}),
                reported_symptoms_json=json.dumps(["Weak airflow"]),
                predicted_fault="Airflow Restriction",
                severity="low",
                severity_rationale="Safe check",
                model_version="1.0.0",
            )
        )
        db.commit()

    resp = client.post(
        "/api/v1/feedback",
        headers=headers,
        json={
            "diagnosis_id": "diag_ac_01",
            "report_id": "rep_ac_01",
            "diagnosis_relevance": "yes",
            "resolution_status": "resolved",
            "was_helpful": True,
            "was_issue_resolved": True,
            "still_needs_professional_assistance": False,
            "comments": "Cleaning the intake filter restored cooling.",
        },
    )
    assert resp.status_code == 201
    assert resp.json()["diagnosis_id"] == "diag_ac_01"

    with app.state.session_factory() as db:
        assert db.scalar(select(func.count(FeedbackORM.id))) == 1
        diag = db.get(DiagnosisORM, "diag_ac_01")
        assert diag is not None and diag.status == "resolved"
