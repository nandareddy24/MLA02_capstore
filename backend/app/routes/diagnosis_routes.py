"""Diagnosis inference, decision support, history, catalog, and RBAC summary routes."""

from __future__ import annotations

import json
import logging
import time
import uuid
from datetime import datetime, timezone
from pathlib import Path
from typing import Optional

from fastapi import APIRouter, Depends, Query, status
from fastapi.responses import JSONResponse
from sqlalchemy import func, or_, select
from sqlalchemy.orm import Session, selectinload

from ..db_models import (
    DeviceORM,
    DiagnosisORM,
    FeedbackORM,
    RecommendationORM,
    UserORM,
)
from ..decision_support import build_evidence, build_uncertainty_notice, evaluate_severity
from ..decision_support_service import DecisionSupportService
from ..model_registry import ModelNotAvailableError, ModelRegistry
from ..schemas import (
    AlternativeFault,
    DecisionSupportPlan,
    DecisionSupportRequest,
    DeviceInfoPayload,
    DiagnosisRequest,
    DiagnosisResponse,
    DiagnosticEvidence,
    ErrorResponse,
    HistoryRecordSummary,
    PaginatedHistoryResponse,
    RecommendationItem,
    UncertaintyNotice,
)
from ..security import require_roles

logger = logging.getLogger("fixwise.diagnosis")


def _ensure_utc(dt: datetime) -> datetime:
    if dt.tzinfo is None:
        return dt.replace(tzinfo=timezone.utc)
    return dt.astimezone(timezone.utc)


def _parse_iso_date(raw: Optional[str], *, end_of_day: bool = False) -> Optional[datetime]:
    if not raw or not raw.strip():
        return None
    text = raw.strip()
    try:
        if len(text) == 10:
            parsed = datetime.fromisoformat(text)
            if end_of_day:
                parsed = parsed.replace(hour=23, minute=59, second=59, microsecond=999999)
            return parsed.replace(tzinfo=timezone.utc)
        parsed = datetime.fromisoformat(text.replace("Z", "+00:00"))
        return _ensure_utc(parsed)
    except ValueError:
        return None


def _reconstruct_diagnosis_response(record: DiagnosisORM) -> DiagnosisResponse:
    """Rebuilds the exact preserved DiagnosisResponse snapshot from stored ORM rows
    without ever re-running ML inference.
    """
    device_payload = DeviceInfoPayload(**json.loads(record.device_details_json))
    alternatives = [
        AlternativeFault(**item)
        for item in json.loads(record.alternative_faults_json or "[]")
    ]
    evidence = [
        DiagnosticEvidence(**item)
        for item in json.loads(record.evidence_json or "[]")
    ]
    raw_uncertainty = json.loads(record.uncertainty_json or "{}")
    if "is_uncertain" not in raw_uncertainty:
        raw_uncertainty = {
            "is_uncertain": True,
            "message": "Preserved historical diagnosis record.",
        }
    uncertainty = UncertaintyNotice(**raw_uncertainty)
    ds_plan = (
        DecisionSupportPlan(**json.loads(record.decision_support_plan_json))
        if record.decision_support_plan_json
        else None
    )

    if ds_plan is not None and ds_plan.recommendations:
        recommendations = ds_plan.recommendations
    else:
        recommendations = [
            RecommendationItem(
                id=rec.id,
                step_number=rec.step_number,
                title=rec.title,
                instructions=rec.recommended_action,
                description=rec.recommended_action,
                risk_level=(
                    rec.risk_level
                    if rec.risk_level in ("safe", "caution", "high")
                    else "caution"
                ),
                is_checkable=rec.is_checkable,
                safety_note=rec.safety_information,
            )
            for rec in record.recommendations
        ]

    symptoms = json.loads(record.reported_symptoms_json or "[]")
    summary = (
        f"Based on {len(symptoms)} reported symptom(s) for "
        f"{record.device_name}, the most probable fault category is "
        f"{record.predicted_fault}. Severity is assessed as {record.severity.upper()} "
        f"via decision-support safety rules."
    )

    return DiagnosisResponse(
        diagnosis_id=record.id,
        report_id=record.report_id,
        device=device_payload,
        predicted_fault_category=record.predicted_fault,
        primary_fault=record.predicted_fault,
        ranked_alternatives=alternatives,
        confidence=record.confidence,
        confidence_is_calibrated=record.confidence_is_calibrated,
        severity=(
            record.severity
            if record.severity in ("low", "medium", "high", "critical")
            else "medium"
        ),
        severity_rationale=record.severity_rationale,
        evidence=evidence,
        contributing_factors=[item.detail for item in evidence],
        recommendations=recommendations,
        decision_support_plan=ds_plan,
        uncertainty=uncertainty,
        summary=summary,
        model_version=record.model_version,
        algorithm=record.algorithm,
        processing_time_ms=record.processing_time_ms,
        analyzed_at=_ensure_utc(record.created_at),
    )


def build_diagnosis_router(
    *,
    get_db,
    get_current_user,
    registry: ModelRegistry,
    decision_support: DecisionSupportService,
    catalog_path: Path,
) -> APIRouter:
    router = APIRouter(prefix="/api/v1", tags=["diagnosis"])
    require_admin_or_reviewer = require_roles(get_current_user, {"admin", "reviewer"})

    @router.get("/catalog/devices")
    def get_device_catalog() -> JSONResponse:
        if not catalog_path.exists():
            return JSONResponse(
                status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
                content=ErrorResponse(
                    code="CATALOG_UNAVAILABLE",
                    message="Diagnostic device catalog configuration was not found.",
                ).model_dump(),
            )
        with catalog_path.open("r", encoding="utf-8") as fp:
            return JSONResponse(status_code=status.HTTP_200_OK, content=json.load(fp))

    @router.post(
        "/decision-support/recommend",
        response_model=DecisionSupportPlan,
    )
    def generate_recommendations(
        payload: DecisionSupportRequest,
        _current_user: UserORM = Depends(get_current_user),
    ) -> JSONResponse:
        plan = decision_support.build_plan(payload)
        return JSONResponse(
            status_code=status.HTTP_200_OK,
            content=plan.model_dump(mode="json"),
        )

    @router.post(
        "/diagnosis/analyze",
        response_model=DiagnosisResponse,
        responses={
            401: {"model": ErrorResponse},
            422: {"model": ErrorResponse},
            503: {"model": ErrorResponse},
            500: {"model": ErrorResponse},
        },
    )
    def analyze_fault(
        payload: DiagnosisRequest,
        current_user: UserORM = Depends(get_current_user),
        db: Session = Depends(get_db),
    ) -> JSONResponse:
        # Duplicate-submission protection: if this user already submitted this
        # report_id, return the preserved diagnosis snapshot instead of duplicating.
        existing = db.scalar(
            select(DiagnosisORM)
            .options(selectinload(DiagnosisORM.recommendations))
            .where(
                DiagnosisORM.user_id == current_user.id,
                DiagnosisORM.report_id == payload.report_id,
            )
        )
        if existing is not None:
            preserved = _reconstruct_diagnosis_response(existing)
            return JSONResponse(
                status_code=status.HTTP_200_OK,
                content=preserved.model_dump(mode="json"),
            )

        started = time.perf_counter()
        diagnosis_id = f"diag_{uuid.uuid4().hex[:12]}"

        try:
            prediction = registry.predict(payload)
        except ModelNotAvailableError as exc:
            logger.warning("Diagnosis requested while model artifact unavailable: %s", exc)
            return JSONResponse(
                status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
                content=ErrorResponse(
                    code="MODEL_INTEGRATION_PENDING",
                    message=str(exc),
                ).model_dump(),
            )
        except Exception:
            logger.exception("Unexpected diagnosis inference failure")
            return JSONResponse(
                status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
                content=ErrorResponse(
                    code="INFERENCE_ERROR",
                    message="Diagnosis inference failed unexpectedly. Please try again later.",
                ).model_dump(),
            )

        # Server-side severity & safety evaluation (never trusted from client).
        severity, severity_rationale = evaluate_severity(
            payload,
            prediction.predicted_fault,
        )
        evidence = build_evidence(payload)
        uncertainty = build_uncertainty_notice(
            top_probability=prediction.confidence,
            ranked_alternatives=prediction.ranked_alternatives,
            confidence_is_calibrated=prediction.confidence_is_calibrated,
        )
        ds_plan = decision_support.build_plan(
            DecisionSupportRequest(
                diagnosis_id=diagnosis_id,
                report_id=payload.report_id,
                device_category=payload.device.category,
                device_name=payload.device.name,
                predicted_fault=prediction.predicted_fault,
                symptoms=payload.symptoms,
                description=payload.description,
                operating_conditions=payload.operating_conditions,
            )
        )

        elapsed_ms = round((time.perf_counter() - started) * 1000.0, 2)
        analyzed_at = datetime.now(timezone.utc)

        # Link to a persisted DeviceORM only if owned by the authenticated user.
        linked_device_id: Optional[str] = None
        if payload.device.id:
            owned_device = db.scalar(
                select(DeviceORM).where(
                    DeviceORM.id == payload.device.id,
                    DeviceORM.user_id == current_user.id,
                )
            )
            if owned_device is not None:
                linked_device_id = owned_device.id

        diagnosis_row = DiagnosisORM(
            id=diagnosis_id,
            report_id=payload.report_id,
            user_id=current_user.id,
            device_id=linked_device_id,
            device_category=payload.device.category,
            device_name=payload.device.name,
            device_details_json=json.dumps(payload.device.model_dump(mode="json")),
            reported_symptoms_json=json.dumps(payload.symptoms),
            error_code=payload.error_code,
            predicted_fault=prediction.predicted_fault,
            alternative_faults_json=json.dumps(
                [alt.model_dump(mode="json") for alt in prediction.ranked_alternatives]
            ),
            confidence=prediction.confidence,
            confidence_is_calibrated=prediction.confidence_is_calibrated,
            severity=severity,
            severity_rationale=severity_rationale,
            evidence_json=json.dumps([item.model_dump(mode="json") for item in evidence]),
            uncertainty_json=json.dumps(uncertainty.model_dump(mode="json")),
            decision_support_plan_json=json.dumps(ds_plan.model_dump(mode="json")),
            model_version=prediction.model_version,
            algorithm=prediction.algorithm,
            processing_time_ms=elapsed_ms,
            status="diagnosed",
            created_at=analyzed_at,
        )
        db.add(diagnosis_row)

        for rec in ds_plan.recommendations:
            db.add(
                RecommendationORM(
                    id=f"rec_{uuid.uuid4().hex[:12]}",
                    diagnosis_id=diagnosis_id,
                    fault_category=prediction.predicted_fault,
                    step_number=rec.step_number,
                    title=rec.title,
                    recommended_action=rec.instructions,
                    risk_level=rec.risk_level,
                    is_checkable=rec.is_checkable,
                    safety_information=rec.safety_note
                    or ("; ".join(ds_plan.safety_warnings) if ds_plan.safety_warnings else None),
                    review_status=ds_plan.expert_review_status,
                )
            )

        db.commit()

        summary = (
            f"Based on {len(payload.symptoms)} reported symptom(s) for "
            f"{payload.device.name}, the most probable fault category is "
            f"{prediction.predicted_fault}. Severity is assessed as {severity.upper()} "
            f"via decision-support safety rules."
        )

        response_model = DiagnosisResponse(
            diagnosis_id=diagnosis_id,
            report_id=payload.report_id,
            device=payload.device,
            predicted_fault_category=prediction.predicted_fault,
            primary_fault=prediction.predicted_fault,
            ranked_alternatives=prediction.ranked_alternatives,
            confidence=prediction.confidence,
            confidence_is_calibrated=prediction.confidence_is_calibrated,
            severity=severity,
            severity_rationale=severity_rationale,
            evidence=evidence,
            contributing_factors=[item.detail for item in evidence],
            recommendations=ds_plan.recommendations,
            decision_support_plan=ds_plan,
            uncertainty=uncertainty,
            summary=summary,
            model_version=prediction.model_version,
            algorithm=prediction.algorithm,
            processing_time_ms=elapsed_ms,
            analyzed_at=analyzed_at,
        )

        return JSONResponse(
            status_code=status.HTTP_200_OK,
            content=response_model.model_dump(mode="json"),
        )

    @router.get("/diagnosis/{report_id}/recommendations")
    def get_saved_recommendations(
        report_id: str,
        current_user: UserORM = Depends(get_current_user),
        db: Session = Depends(get_db),
    ) -> JSONResponse:
        record = db.scalar(
            select(DiagnosisORM)
            .options(selectinload(DiagnosisORM.recommendations))
            .where(
                DiagnosisORM.user_id == current_user.id,
                DiagnosisORM.report_id == report_id,
            )
        )
        if record is None:
            return JSONResponse(
                status_code=status.HTTP_404_NOT_FOUND,
                content=ErrorResponse(
                    code="RECORD_NOT_FOUND",
                    message="Diagnosis recommendations not found for the authenticated user.",
                ).model_dump(),
            )

        if record.decision_support_plan_json:
            return JSONResponse(
                status_code=status.HTTP_200_OK,
                content=json.loads(record.decision_support_plan_json),
            )

        return JSONResponse(
            status_code=status.HTTP_200_OK,
            content={
                "diagnosis_id": record.id,
                "report_id": record.report_id,
                "predicted_fault": record.predicted_fault,
                "recommendations": [
                    {
                        "id": rec.id,
                        "step_number": rec.step_number,
                        "title": rec.title,
                        "instructions": rec.recommended_action,
                        "risk_level": rec.risk_level,
                        "is_checkable": rec.is_checkable,
                        "safety_note": rec.safety_information,
                        "review_status": rec.review_status,
                    }
                    for rec in record.recommendations
                ],
            },
        )

    @router.get("/history", response_model=PaginatedHistoryResponse)
    def get_user_history(
        current_user: UserORM = Depends(get_current_user),
        db: Session = Depends(get_db),
        search: Optional[str] = Query(default=None),
        severity: Optional[str] = Query(default=None),
        date_from: Optional[str] = Query(default=None),
        date_to: Optional[str] = Query(default=None),
        sort: str = Query(default="newest", pattern="^(newest|oldest)$"),
        page: int = Query(default=1, ge=1),
        page_size: int = Query(default=20, ge=1, le=100),
    ) -> JSONResponse:
        conditions = [DiagnosisORM.user_id == current_user.id]

        if search and search.strip():
            pattern = f"%{search.strip()}%"
            conditions.append(
                or_(
                    DiagnosisORM.device_name.ilike(pattern),
                    DiagnosisORM.device_category.ilike(pattern),
                    DiagnosisORM.predicted_fault.ilike(pattern),
                )
            )

        if severity and severity.strip():
            sev = severity.strip().lower()
            if sev == "safe":
                conditions.append(DiagnosisORM.severity == "low")
            elif sev == "high":
                conditions.append(DiagnosisORM.severity.in_(["high", "critical"]))
            else:
                conditions.append(DiagnosisORM.severity == sev)

        parsed_from = _parse_iso_date(date_from, end_of_day=False)
        if parsed_from is not None:
            conditions.append(DiagnosisORM.created_at >= parsed_from)

        parsed_to = _parse_iso_date(date_to, end_of_day=True)
        if parsed_to is not None:
            conditions.append(DiagnosisORM.created_at <= parsed_to)

        total = (
            db.scalar(select(func.count(DiagnosisORM.id)).where(*conditions)) or 0
        )

        order_clause = (
            DiagnosisORM.created_at.asc()
            if sort == "oldest"
            else DiagnosisORM.created_at.desc()
        )
        offset = (page - 1) * page_size
        rows = db.scalars(
            select(DiagnosisORM)
            .options(selectinload(DiagnosisORM.feedback))
            .where(*conditions)
            .order_by(order_clause)
            .limit(page_size)
            .offset(offset)
        ).all()

        items = [
            HistoryRecordSummary(
                report_id=row.report_id,
                diagnosis_id=row.id,
                user_id=row.user_id,
                device_name=row.device_name,
                device_category=row.device_category,
                predicted_fault=row.predicted_fault,
                severity=(
                    row.severity
                    if row.severity in ("low", "medium", "high", "critical")
                    else "medium"
                ),
                status=(
                    row.status
                    if row.status in ("pendingDiagnosis", "diagnosed", "resolved")
                    else "diagnosed"
                ),
                diagnosed_at=_ensure_utc(row.created_at),
                has_feedback=len(row.feedback) > 0,
            )
            for row in rows
        ]

        response = PaginatedHistoryResponse(
            items=items,
            total=int(total),
            page=page,
            page_size=page_size,
            has_more=(page * page_size) < int(total),
        )
        return JSONResponse(
            status_code=status.HTTP_200_OK,
            content=response.model_dump(mode="json"),
        )

    @router.get("/history/{report_id}")
    def get_history_record_detail(
        report_id: str,
        current_user: UserORM = Depends(get_current_user),
        db: Session = Depends(get_db),
    ) -> JSONResponse:
        record = db.scalar(
            select(DiagnosisORM)
            .options(
                selectinload(DiagnosisORM.recommendations),
                selectinload(DiagnosisORM.feedback),
            )
            .where(
                DiagnosisORM.user_id == current_user.id,
                DiagnosisORM.report_id == report_id,
            )
        )
        if record is None:
            return JSONResponse(
                status_code=status.HTTP_404_NOT_FOUND,
                content=ErrorResponse(
                    code="RECORD_NOT_FOUND",
                    message="Diagnosis record not found for the authenticated user.",
                ).model_dump(),
            )

        preserved = _reconstruct_diagnosis_response(record)
        fb_row: Optional[FeedbackORM] = record.feedback[0] if record.feedback else None
        feedback_payload = (
            {
                "id": fb_row.id,
                "user_id": fb_row.user_id,
                "diagnosis_id": fb_row.diagnosis_id,
                "report_id": fb_row.report_id,
                "diagnosis_relevance": fb_row.relevance_rating,
                "resolution_status": fb_row.resolution_status,
                "was_helpful": fb_row.was_helpful,
                "was_issue_resolved": fb_row.was_issue_resolved,
                "still_needs_professional_assistance": fb_row.still_needs_professional_assistance,
                "comments": fb_row.comments,
                "submitted_at": _ensure_utc(fb_row.created_at).isoformat(),
                "updated_at": _ensure_utc(fb_row.updated_at).isoformat(),
            }
            if fb_row is not None
            else None
        )

        return JSONResponse(
            status_code=status.HTTP_200_OK,
            content={
                "report_id": record.report_id,
                "diagnosis_id": record.id,
                "user_id": record.user_id,
                "device": json.loads(record.device_details_json),
                "symptoms": json.loads(record.reported_symptoms_json),
                "error_code": record.error_code,
                "predicted_fault": record.predicted_fault,
                "severity": record.severity,
                "status": record.status,
                "model_version": record.model_version,
                "diagnosed_at": _ensure_utc(record.created_at).isoformat(),
                "diagnosis": preserved.model_dump(mode="json"),
                "feedback": feedback_payload,
            },
        )

    @router.get("/admin/diagnostics/summary")
    def admin_diagnostics_summary(
        _admin_user: UserORM = Depends(require_admin_or_reviewer),
        db: Session = Depends(get_db),
    ) -> JSONResponse:
        total_users = db.scalar(select(func.count(UserORM.id))) or 0
        total_diagnoses = db.scalar(select(func.count(DiagnosisORM.id))) or 0
        total_feedback = db.scalar(select(func.count(FeedbackORM.id))) or 0
        return JSONResponse(
            status_code=status.HTTP_200_OK,
            content={
                "total_users": int(total_users),
                "total_diagnoses": int(total_diagnoses),
                "total_feedback": int(total_feedback),
            },
        )

    return router
