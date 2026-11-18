"""Pydantic v2 request/response contracts with strict validation and text sanitization."""

from __future__ import annotations

import re
from datetime import datetime
from typing import Literal, Optional

from pydantic import BaseModel, Field, field_validator, model_validator

_CONTROL_CHARS_RE = re.compile(r"[\x00-\x08\x0b\x0c\x0e-\x1f\x7f]")
_MULTI_SPACE_RE = re.compile(r"[ \t]{2,}")
_EMAIL_RE = re.compile(r"^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$")
_OTP_RE = re.compile(r"^\d{6}$")


def sanitize_text(value: Optional[str]) -> Optional[str]:
    """Removes control characters and normalizes whitespace in user-supplied text."""
    if value is None:
        return None
    cleaned = _CONTROL_CHARS_RE.sub("", value).strip()
    cleaned = _MULTI_SPACE_RE.sub(" ", cleaned)
    return cleaned or None


def normalize_email(value: str) -> str:
    cleaned = sanitize_text(value) if isinstance(value, str) else None
    if not cleaned or not _EMAIL_RE.match(cleaned):
        raise ValueError("Please provide a valid email address.")
    return cleaned.lower()


def validate_strong_password(password: str) -> str:
    """Enforces strong password rules aligned with the FixWise Flutter client."""
    if len(password) < 8:
        raise ValueError("Password must be at least 8 characters long.")
    if not re.search(r"[A-Z]", password):
        raise ValueError("Password must include at least one uppercase letter.")
    if not re.search(r"[a-z]", password):
        raise ValueError("Password must include at least one lowercase letter.")
    if not re.search(r"\d", password):
        raise ValueError("Password must include at least one number.")
    if not re.search(r"[^A-Za-z0-9]", password):
        raise ValueError("Password must include at least one special character.")
    return password


# ---------------------------------------------------------------------------
# Authentication & User Profile Contracts
# ---------------------------------------------------------------------------


class RegisterRequest(BaseModel):
    full_name: Optional[str] = Field(default=None, min_length=2, max_length=120)
    name: Optional[str] = Field(default=None, min_length=2, max_length=120)
    email: str = Field(min_length=5, max_length=255)
    password: str = Field(min_length=8, max_length=128)
    accepted_terms: bool = True

    @field_validator("full_name", "name", mode="before")
    @classmethod
    def _clean_names(cls, value: Optional[str]) -> Optional[str]:
        if isinstance(value, str):
            return sanitize_text(value)
        return value

    @field_validator("email", mode="before")
    @classmethod
    def _validate_email(cls, value: str) -> str:
        return normalize_email(value)

    @field_validator("password")
    @classmethod
    def _validate_password(cls, value: str) -> str:
        return validate_strong_password(value)

    @model_validator(mode="after")
    def _ensure_name_and_terms(self) -> "RegisterRequest":
        resolved = self.full_name or self.name
        if not resolved or len(resolved) < 2:
            raise ValueError("Full name must be at least 2 characters.")
        self.full_name = resolved
        if not self.accepted_terms:
            raise ValueError("Terms and Conditions must be accepted to register.")
        return self


class LoginRequest(BaseModel):
    email: str = Field(min_length=5, max_length=255)
    password: str = Field(min_length=1, max_length=128)
    remember_me: bool = True

    @field_validator("email", mode="before")
    @classmethod
    def _validate_email(cls, value: str) -> str:
        return normalize_email(value)


class RefreshTokenRequest(BaseModel):
    refresh_token: str = Field(min_length=16, max_length=2048)


class LogoutRequest(BaseModel):
    refresh_token: Optional[str] = Field(default=None, max_length=2048)


class OtpSendRequest(BaseModel):
    email: str = Field(min_length=5, max_length=255)
    purpose: Literal["registration", "login", "password_reset", "email_verification"] = (
        "email_verification"
    )

    @field_validator("email", mode="before")
    @classmethod
    def _validate_email(cls, value: str) -> str:
        return normalize_email(value)


class OtpVerifyRequest(BaseModel):
    email: str = Field(min_length=5, max_length=255)
    code: Optional[str] = Field(default=None, max_length=12)
    otp: Optional[str] = Field(default=None, max_length=12)
    purpose: Literal["registration", "login", "password_reset", "email_verification"] = (
        "email_verification"
    )

    @field_validator("email", mode="before")
    @classmethod
    def _validate_email(cls, value: str) -> str:
        return normalize_email(value)

    @model_validator(mode="after")
    def _resolve_code(self) -> "OtpVerifyRequest":
        raw = (self.code or self.otp or "").strip()
        if not _OTP_RE.match(raw):
            raise ValueError("Verification code must be a 6-digit number.")
        self.code = raw
        return self


class ForgotPasswordRequest(BaseModel):
    email: str = Field(min_length=5, max_length=255)

    @field_validator("email", mode="before")
    @classmethod
    def _validate_email(cls, value: str) -> str:
        return normalize_email(value)


class ResetPasswordRequest(BaseModel):
    email: str = Field(min_length=5, max_length=255)
    code: Optional[str] = Field(default=None, max_length=12)
    otp: Optional[str] = Field(default=None, max_length=12)
    new_password: str = Field(min_length=8, max_length=128)

    @field_validator("email", mode="before")
    @classmethod
    def _validate_email(cls, value: str) -> str:
        return normalize_email(value)

    @field_validator("new_password")
    @classmethod
    def _validate_password(cls, value: str) -> str:
        return validate_strong_password(value)

    @model_validator(mode="after")
    def _resolve_code(self) -> "ResetPasswordRequest":
        raw = (self.code or self.otp or "").strip()
        if not _OTP_RE.match(raw):
            raise ValueError("Reset verification code must be a 6-digit number.")
        self.code = raw
        return self


class AuthUserResponse(BaseModel):
    id: str
    full_name: str
    name: str
    email: str
    role: str
    account_status: str
    created_at: datetime


class AuthTokenResponse(BaseModel):
    access_token: str
    refresh_token: str
    token_type: str = "bearer"
    expires_at: datetime
    expires_in: int
    user: AuthUserResponse
    message: Optional[str] = None


class ProfileUpdateRequest(BaseModel):
    full_name: str = Field(min_length=2, max_length=120)
    role: Optional[str] = Field(default=None, min_length=2, max_length=80)

    @field_validator("full_name", "role", mode="before")
    @classmethod
    def _clean_profile_fields(cls, value: Optional[str]) -> Optional[str]:
        if value is None:
            return None
        cleaned = sanitize_text(value) if isinstance(value, str) else None
        if not cleaned:
            raise ValueError("Field cannot be blank.")
        return cleaned


class ChangePasswordRequest(BaseModel):
    current_password: str = Field(min_length=1, max_length=128)
    new_password: str = Field(min_length=8, max_length=128)

    @field_validator("new_password")
    @classmethod
    def _validate_new_password(cls, value: str) -> str:
        return validate_strong_password(value)


# ---------------------------------------------------------------------------
# Device Management Contracts
# ---------------------------------------------------------------------------


class DeviceCreateRequest(BaseModel):
    category: str = Field(min_length=1, max_length=64)
    manufacturer: Optional[str] = Field(default="", max_length=80)
    model: Optional[str] = Field(default="", max_length=100)
    device_age: Optional[str] = Field(default=None, max_length=64)
    operating_environment: Optional[str] = Field(default=None, max_length=64)

    @field_validator(
        "category",
        "manufacturer",
        "model",
        "device_age",
        "operating_environment",
        mode="before",
    )
    @classmethod
    def _clean_device_fields(cls, value: Optional[str]) -> Optional[str]:
        if isinstance(value, str):
            return sanitize_text(value)
        return value


class DeviceResponse(BaseModel):
    id: str
    user_id: str
    category: str
    manufacturer: str
    model: str
    device_age: Optional[str] = None
    operating_environment: Optional[str] = None
    created_at: datetime


# ---------------------------------------------------------------------------
# Diagnosis, Decision Support, History & Feedback Contracts
# ---------------------------------------------------------------------------


class DeviceInfoPayload(BaseModel):
    id: Optional[str] = Field(default=None, max_length=120)
    name: str = Field(min_length=1, max_length=160)
    category: str = Field(min_length=1, max_length=64)
    manufacturer: Optional[str] = Field(default=None, max_length=60)
    model_name: Optional[str] = Field(default=None, max_length=80)
    age: Optional[str] = Field(default=None, max_length=64)
    operating_environment: Optional[str] = Field(default=None, max_length=64)

    @field_validator(
        "name",
        "category",
        "manufacturer",
        "model_name",
        "age",
        "operating_environment",
        mode="before",
    )
    @classmethod
    def _clean_fields(cls, value: Optional[str]) -> Optional[str]:
        if isinstance(value, str):
            return sanitize_text(value)
        return value


class DiagnosisRequest(BaseModel):
    report_id: str = Field(min_length=1, max_length=120)
    device: DeviceInfoPayload
    title: Optional[str] = Field(default=None, max_length=160)
    symptoms: list[str] = Field(min_length=1, max_length=30)
    error_code: Optional[str] = Field(default=None, max_length=64)
    started_when: Optional[str] = Field(default=None, max_length=64)
    operating_conditions: Optional[str] = Field(default=None, max_length=240)
    description: Optional[str] = Field(default=None, max_length=1000)
    reported_at: Optional[datetime] = None

    @field_validator("symptoms", mode="before")
    @classmethod
    def _clean_symptoms(cls, value: list[str]) -> list[str]:
        if not isinstance(value, list):
            raise ValueError("symptoms must be a list of non-empty strings.")
        cleaned: list[str] = []
        seen: set[str] = set()
        for item in value:
            if not isinstance(item, str):
                continue
            text = sanitize_text(item)
            if text and text.lower() not in seen:
                seen.add(text.lower())
                cleaned.append(text)
        if not cleaned:
            raise ValueError("At least one valid symptom is required.")
        return cleaned

    @field_validator(
        "title",
        "error_code",
        "started_when",
        "operating_conditions",
        "description",
        mode="before",
    )
    @classmethod
    def _clean_optional_text(cls, value: Optional[str]) -> Optional[str]:
        if isinstance(value, str):
            return sanitize_text(value)
        return value


class AlternativeFault(BaseModel):
    fault_category: str
    probability: Optional[float] = Field(default=None, ge=0.0, le=1.0)


class DiagnosticEvidence(BaseModel):
    signal_type: Literal["symptom", "error_code", "context"]
    source: str
    detail: str


class UncertaintyNotice(BaseModel):
    is_uncertain: bool
    message: Optional[str] = None
    disclaimer: str = (
        "A predicted fault category is decision support based on reported symptoms "
        "and is not a confirmed physical fault. Verify safely or consult a qualified technician."
    )


class RecommendationItem(BaseModel):
    id: str
    step_number: int = Field(ge=1)
    title: str
    instructions: str
    description: Optional[str] = None
    priority: Literal["low", "medium", "high"] = "medium"
    risk_level: Literal["safe", "caution", "high"] = "caution"
    is_checkable: bool = False
    safety_note: Optional[str] = None
    estimated_minutes: Optional[int] = None
    required_tools: list[str] = Field(default_factory=list)
    rank_score: Optional[float] = Field(default=None, ge=0.0, le=1.0)


class EscalationGuidance(BaseModel):
    requires_technician: bool
    stop_using_device: bool
    when_to_escalate: str
    emergency_guidance: Optional[str] = None


class DecisionSupportRequest(BaseModel):
    diagnosis_id: str = Field(min_length=1, max_length=120)
    report_id: str = Field(min_length=1, max_length=120)
    device_category: str = Field(min_length=1, max_length=64)
    device_name: Optional[str] = Field(default=None, max_length=160)
    predicted_fault: str = Field(min_length=1, max_length=160)
    symptoms: list[str] = Field(min_length=1, max_length=30)
    description: Optional[str] = Field(default=None, max_length=1000)
    operating_conditions: Optional[str] = Field(default=None, max_length=240)


class DecisionSupportPlan(BaseModel):
    diagnosis_id: str
    report_id: str
    predicted_fault: str
    device_category: str
    device_name: str
    severity: Literal["safe", "medium", "high"]
    severity_rationale: str
    is_dangerous_fault: bool = False
    immediate_safety_banner: Optional[str] = None
    likely_cause: str
    first_recommended_check: Optional[RecommendationItem] = None
    recommendations: list[RecommendationItem] = Field(default_factory=list)
    safety_warnings: list[str] = Field(default_factory=list)
    escalation: EscalationGuidance
    expert_review_status: str = "reviewed"
    knowledge_base_record_id: Optional[str] = None


DiagnosisRelevance = Literal["yes", "partially", "no"]
ResolutionStatus = Literal[
    "resolved",
    "partially_resolved",
    "not_resolved",
    "not_attempted",
]


class FeedbackSubmissionRequest(BaseModel):
    id: Optional[str] = Field(default=None, max_length=120)
    diagnosis_id: Optional[str] = Field(default=None, max_length=120)
    report_id: str = Field(min_length=1, max_length=120)
    diagnosis_relevance: DiagnosisRelevance = "yes"
    resolution_status: ResolutionStatus = "not_attempted"
    was_helpful: Optional[bool] = None
    was_issue_resolved: Optional[bool] = None
    still_needs_professional_assistance: bool = False
    rating: Optional[int] = Field(default=None, ge=1, le=5)
    comments: Optional[str] = Field(default=None, max_length=1000)

    @field_validator("comments", mode="before")
    @classmethod
    def _clean_comments(cls, value: Optional[str]) -> Optional[str]:
        if isinstance(value, str):
            return sanitize_text(value)
        return value


class HistoryRecordSummary(BaseModel):
    report_id: str
    diagnosis_id: str
    user_id: str
    device_name: str
    device_category: str
    predicted_fault: str
    severity: Literal["low", "medium", "high", "critical"]
    status: Literal["pendingDiagnosis", "diagnosed", "resolved"]
    diagnosed_at: datetime
    has_feedback: bool = False


class PaginatedHistoryResponse(BaseModel):
    items: list[HistoryRecordSummary]
    total: int
    page: int
    page_size: int
    has_more: bool


class DiagnosisResponse(BaseModel):
    diagnosis_id: str
    report_id: str
    device: DeviceInfoPayload
    predicted_fault_category: str
    primary_fault: str
    ranked_alternatives: list[AlternativeFault] = Field(default_factory=list)
    confidence: Optional[float] = Field(default=None, ge=0.0, le=1.0)
    confidence_is_calibrated: bool = False
    severity: Literal["low", "medium", "high", "critical"]
    severity_rationale: str
    evidence: list[DiagnosticEvidence] = Field(default_factory=list)
    contributing_factors: list[str] = Field(default_factory=list)
    recommendations: list[RecommendationItem] = Field(default_factory=list)
    decision_support_plan: Optional[DecisionSupportPlan] = None
    uncertainty: UncertaintyNotice
    summary: str
    model_version: str
    algorithm: str
    processing_time_ms: float
    analyzed_at: datetime


class ErrorResponse(BaseModel):
    code: str
    message: str
    details: Optional[dict] = None
