"""User-scoped post-diagnosis feedback endpoints with duplicate prevention."""

from __future__ import annotations

import uuid
from datetime import datetime, timezone

from fastapi import APIRouter, Depends, status
from fastapi.responses import JSONResponse
from sqlalchemy import select
from sqlalchemy.orm import Session

from ..db_models import DiagnosisORM, FeedbackORM, UserORM
from ..schemas import ErrorResponse, FeedbackSubmissionRequest


def build_feedback_router(*, get_db, get_current_user) -> APIRouter:
    router = APIRouter(prefix="/api/v1/feedback", tags=["feedback"])

    @router.post("")
    @router.put("")
    def submit_feedback(
        payload: FeedbackSubmissionRequest,
        current_user: UserORM = Depends(get_current_user),
        db: Session = Depends(get_db),
    ) -> JSONResponse:
        # Enforce ownership: a user can only submit feedback for their own diagnosis.
        diagnosis = db.scalar(
            select(DiagnosisORM).where(
                DiagnosisORM.user_id == current_user.id,
                DiagnosisORM.report_id == payload.report_id,
            )
        )
        if diagnosis is None and payload.diagnosis_id:
            diagnosis = db.scalar(
                select(DiagnosisORM).where(
                    DiagnosisORM.user_id == current_user.id,
                    DiagnosisORM.id == payload.diagnosis_id,
                )
            )
        if diagnosis is None:
            return JSONResponse(
                status_code=status.HTTP_404_NOT_FOUND,
                content=ErrorResponse(
                    code="RECORD_NOT_FOUND",
                    message="Diagnosis record not found for the authenticated user.",
                ).model_dump(),
            )

        was_helpful = (
            payload.was_helpful
            if payload.was_helpful is not None
            else payload.diagnosis_relevance != "no"
        )
        was_resolved = (
            payload.was_issue_resolved
            if payload.was_issue_resolved is not None
            else payload.resolution_status == "resolved"
        )
        now = datetime.now(timezone.utc)

        existing = db.scalar(
            select(FeedbackORM).where(
                FeedbackORM.user_id == current_user.id,
                FeedbackORM.diagnosis_id == diagnosis.id,
            )
        )

        if existing is not None:
            existing.relevance_rating = payload.diagnosis_relevance
            existing.resolution_status = payload.resolution_status
            existing.was_helpful = was_helpful
            existing.was_issue_resolved = was_resolved
            existing.still_needs_professional_assistance = (
                payload.still_needs_professional_assistance
            )
            existing.comments = payload.comments
            existing.updated_at = now
            db.add(existing)
            effective_id = existing.id
            was_updated = True
        else:
            effective_id = payload.id or f"fb_{uuid.uuid4().hex[:12]}"
            row = FeedbackORM(
                id=effective_id,
                user_id=current_user.id,
                diagnosis_id=diagnosis.id,
                report_id=diagnosis.report_id,
                relevance_rating=payload.diagnosis_relevance,
                resolution_status=payload.resolution_status,
                was_helpful=was_helpful,
                was_issue_resolved=was_resolved,
                still_needs_professional_assistance=payload.still_needs_professional_assistance,
                comments=payload.comments,
                created_at=now,
                updated_at=now,
            )
            db.add(row)
            was_updated = False

        if was_resolved or payload.resolution_status == "resolved":
            diagnosis.status = "resolved"
            db.add(diagnosis)

        db.commit()

        return JSONResponse(
            status_code=status.HTTP_200_OK if was_updated else status.HTTP_201_CREATED,
            content={
                "status": "updated" if was_updated else "recorded",
                "feedback_id": effective_id,
                "diagnosis_id": diagnosis.id,
                "report_id": diagnosis.report_id,
                "user_id": current_user.id,
            },
        )

    return router
