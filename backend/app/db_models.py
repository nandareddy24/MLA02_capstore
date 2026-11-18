"""SQLAlchemy 2.0 relational ORM schema for FixWise (MySQL 8 compatible).

Tables:
- users
- otp_codes
- revoked_tokens
- devices
- diagnoses
- recommendations
- feedback
"""

from __future__ import annotations

from datetime import datetime, timezone

from sqlalchemy import (
    Boolean,
    DateTime,
    Float,
    ForeignKey,
    Index,
    Integer,
    String,
    Text,
    UniqueConstraint,
)
from sqlalchemy.orm import Mapped, mapped_column, relationship

from .database import Base


def _utcnow() -> datetime:
    return datetime.now(timezone.utc)


class UserORM(Base):
    __tablename__ = "users"

    id: Mapped[str] = mapped_column(String(64), primary_key=True)
    name: Mapped[str] = mapped_column(String(120), nullable=False)
    email: Mapped[str] = mapped_column(String(255), nullable=False, unique=True, index=True)
    password_hash: Mapped[str] = mapped_column(String(255), nullable=False)
    role: Mapped[str] = mapped_column(String(64), nullable=False, default="technician")
    account_status: Mapped[str] = mapped_column(String(32), nullable=False, default="active")
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), nullable=False, default=_utcnow
    )

    devices: Mapped[list["DeviceORM"]] = relationship(
        back_populates="owner", cascade="all, delete-orphan"
    )
    diagnoses: Mapped[list["DiagnosisORM"]] = relationship(
        back_populates="owner", cascade="all, delete-orphan"
    )
    feedback_entries: Mapped[list["FeedbackORM"]] = relationship(
        back_populates="owner", cascade="all, delete-orphan"
    )


class OtpCodeORM(Base):
    __tablename__ = "otp_codes"
    __table_args__ = (Index("idx_otp_email_purpose", "email", "purpose"),)

    id: Mapped[str] = mapped_column(String(64), primary_key=True)
    user_id: Mapped[str | None] = mapped_column(
        String(64), ForeignKey("users.id", ondelete="CASCADE"), nullable=True
    )
    email: Mapped[str] = mapped_column(String(255), nullable=False)
    purpose: Mapped[str] = mapped_column(String(32), nullable=False)
    code_hash: Mapped[str] = mapped_column(String(255), nullable=False)
    expires_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False)
    consumed_at: Mapped[datetime | None] = mapped_column(
        DateTime(timezone=True), nullable=True
    )
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), nullable=False, default=_utcnow
    )


class RevokedTokenORM(Base):
    __tablename__ = "revoked_tokens"

    jti: Mapped[str] = mapped_column(String(64), primary_key=True)
    user_id: Mapped[str] = mapped_column(
        String(64), ForeignKey("users.id", ondelete="CASCADE"), nullable=False
    )
    revoked_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), nullable=False, default=_utcnow
    )


class DeviceORM(Base):
    __tablename__ = "devices"

    id: Mapped[str] = mapped_column(String(64), primary_key=True)
    user_id: Mapped[str] = mapped_column(
        String(64), ForeignKey("users.id", ondelete="CASCADE"), nullable=False, index=True
    )
    category: Mapped[str] = mapped_column(String(64), nullable=False)
    manufacturer: Mapped[str] = mapped_column(String(80), nullable=False, default="")
    model: Mapped[str] = mapped_column(String(100), nullable=False, default="")
    device_age: Mapped[str | None] = mapped_column(String(64), nullable=True)
    operating_environment: Mapped[str | None] = mapped_column(String(64), nullable=True)
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), nullable=False, default=_utcnow
    )

    owner: Mapped[UserORM] = relationship(back_populates="devices")


class DiagnosisORM(Base):
    __tablename__ = "diagnoses"
    __table_args__ = (
        UniqueConstraint("user_id", "report_id", name="uq_diagnoses_user_report"),
        Index("idx_diagnoses_user_created", "user_id", "created_at"),
        Index("idx_diagnoses_user_severity", "user_id", "severity"),
    )

    id: Mapped[str] = mapped_column(String(64), primary_key=True)
    report_id: Mapped[str] = mapped_column(String(120), nullable=False)
    user_id: Mapped[str] = mapped_column(
        String(64), ForeignKey("users.id", ondelete="CASCADE"), nullable=False
    )
    device_id: Mapped[str | None] = mapped_column(
        String(64), ForeignKey("devices.id", ondelete="SET NULL"), nullable=True
    )
    device_category: Mapped[str] = mapped_column(String(64), nullable=False)
    device_name: Mapped[str] = mapped_column(String(160), nullable=False)
    device_details_json: Mapped[str] = mapped_column(Text, nullable=False)
    reported_symptoms_json: Mapped[str] = mapped_column(Text, nullable=False)
    error_code: Mapped[str | None] = mapped_column(String(64), nullable=True)
    predicted_fault: Mapped[str] = mapped_column(String(160), nullable=False)
    alternative_faults_json: Mapped[str] = mapped_column(Text, nullable=False, default="[]")
    confidence: Mapped[float | None] = mapped_column(Float, nullable=True)
    confidence_is_calibrated: Mapped[bool] = mapped_column(
        Boolean, nullable=False, default=False
    )
    severity: Mapped[str] = mapped_column(String(32), nullable=False)
    severity_rationale: Mapped[str] = mapped_column(Text, nullable=False)
    evidence_json: Mapped[str] = mapped_column(Text, nullable=False, default="[]")
    uncertainty_json: Mapped[str] = mapped_column(Text, nullable=False, default="{}")
    decision_support_plan_json: Mapped[str | None] = mapped_column(Text, nullable=True)
    model_version: Mapped[str] = mapped_column(String(64), nullable=False)
    algorithm: Mapped[str] = mapped_column(String(80), nullable=False, default="unknown")
    processing_time_ms: Mapped[float] = mapped_column(Float, nullable=False, default=0.0)
    status: Mapped[str] = mapped_column(String(32), nullable=False, default="diagnosed")
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), nullable=False, default=_utcnow
    )

    owner: Mapped[UserORM] = relationship(back_populates="diagnoses")
    recommendations: Mapped[list["RecommendationORM"]] = relationship(
        back_populates="diagnosis",
        cascade="all, delete-orphan",
        order_by="RecommendationORM.step_number",
    )
    feedback: Mapped[list["FeedbackORM"]] = relationship(
        back_populates="diagnosis", cascade="all, delete-orphan"
    )


class RecommendationORM(Base):
    __tablename__ = "recommendations"

    id: Mapped[str] = mapped_column(String(64), primary_key=True)
    diagnosis_id: Mapped[str] = mapped_column(
        String(64), ForeignKey("diagnoses.id", ondelete="CASCADE"), nullable=False, index=True
    )
    fault_category: Mapped[str] = mapped_column(String(160), nullable=False)
    step_number: Mapped[int] = mapped_column(Integer, nullable=False)
    title: Mapped[str] = mapped_column(String(200), nullable=False)
    recommended_action: Mapped[str] = mapped_column(Text, nullable=False)
    risk_level: Mapped[str] = mapped_column(String(32), nullable=False, default="caution")
    is_checkable: Mapped[bool] = mapped_column(Boolean, nullable=False, default=False)
    safety_information: Mapped[str | None] = mapped_column(Text, nullable=True)
    review_status: Mapped[str] = mapped_column(String(32), nullable=False, default="reviewed")

    diagnosis: Mapped[DiagnosisORM] = relationship(back_populates="recommendations")


class FeedbackORM(Base):
    __tablename__ = "feedback"
    __table_args__ = (
        UniqueConstraint("user_id", "diagnosis_id", name="uq_feedback_user_diagnosis"),
    )

    id: Mapped[str] = mapped_column(String(64), primary_key=True)
    user_id: Mapped[str] = mapped_column(
        String(64), ForeignKey("users.id", ondelete="CASCADE"), nullable=False, index=True
    )
    diagnosis_id: Mapped[str] = mapped_column(
        String(64), ForeignKey("diagnoses.id", ondelete="CASCADE"), nullable=False
    )
    report_id: Mapped[str] = mapped_column(String(120), nullable=False)
    relevance_rating: Mapped[str] = mapped_column(String(32), nullable=False)
    resolution_status: Mapped[str] = mapped_column(String(32), nullable=False)
    was_helpful: Mapped[bool] = mapped_column(Boolean, nullable=False, default=True)
    was_issue_resolved: Mapped[bool] = mapped_column(Boolean, nullable=False, default=False)
    still_needs_professional_assistance: Mapped[bool] = mapped_column(
        Boolean, nullable=False, default=False
    )
    comments: Mapped[str | None] = mapped_column(Text, nullable=True)
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), nullable=False, default=_utcnow
    )
    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), nullable=False, default=_utcnow
    )

    owner: Mapped[UserORM] = relationship(back_populates="feedback_entries")
    diagnosis: Mapped[DiagnosisORM] = relationship(back_populates="feedback")
