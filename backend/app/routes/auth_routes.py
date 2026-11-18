"""Authentication, OTP verification, password management, and user profile routes."""

from __future__ import annotations

import logging
import uuid
from datetime import datetime, timedelta, timezone
from typing import Callable, Optional

from fastapi import APIRouter, Depends, HTTPException, Request, status
from fastapi.responses import JSONResponse
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer
from sqlalchemy import select
from sqlalchemy.orm import Session

from ..config import Settings
from ..db_models import OtpCodeORM, RevokedTokenORM, UserORM
from ..schemas import (
    AuthTokenResponse,
    AuthUserResponse,
    ChangePasswordRequest,
    ErrorResponse,
    ForgotPasswordRequest,
    LoginRequest,
    LogoutRequest,
    OtpSendRequest,
    OtpVerifyRequest,
    ProfileUpdateRequest,
    RefreshTokenRequest,
    RegisterRequest,
    ResetPasswordRequest,
)
from ..security import (
    create_access_token,
    create_refresh_token,
    decode_token,
    generate_six_digit_otp,
    hash_secret,
    verify_secret,
)

logger = logging.getLogger("fixwise.auth")
_bearer_optional = HTTPBearer(auto_error=False)
_PRIVILEGED_ROLES = {"admin", "superadmin", "reviewer"}
_OTP_TTL_MINUTES = 10


def _ensure_utc(dt: datetime) -> datetime:
    if dt.tzinfo is None:
        return dt.replace(tzinfo=timezone.utc)
    return dt.astimezone(timezone.utc)


def _serialize_user(user: UserORM) -> AuthUserResponse:
    return AuthUserResponse(
        id=user.id,
        full_name=user.name,
        name=user.name,
        email=user.email,
        role=user.role,
        account_status=user.account_status,
        created_at=_ensure_utc(user.created_at),
    )


def _issue_token_payload(
    *,
    user: UserORM,
    settings: Settings,
    message: Optional[str] = None,
) -> AuthTokenResponse:
    access_token, expires_at = create_access_token(user=user, settings=settings)
    refresh_token = create_refresh_token(user=user, settings=settings)
    return AuthTokenResponse(
        access_token=access_token,
        refresh_token=refresh_token,
        expires_at=expires_at,
        expires_in=settings.access_token_minutes * 60,
        user=_serialize_user(user),
        message=message,
    )


def build_auth_router(
    *,
    get_db,
    get_current_user,
    settings: Settings,
    otp_dispatcher: Optional[Callable[[str, str, str], None]] = None,
) -> APIRouter:
    router = APIRouter(prefix="/api/v1/auth", tags=["authentication"])

    def _create_and_dispatch_otp(
        db: Session,
        *,
        email: str,
        purpose: str,
        user_id: Optional[str] = None,
        ttl_minutes: int = _OTP_TTL_MINUTES,
    ) -> None:
        code = generate_six_digit_otp()
        now = datetime.now(timezone.utc)
        otp_row = OtpCodeORM(
            id=f"otp_{uuid.uuid4().hex[:12]}",
            user_id=user_id,
            email=email,
            purpose=purpose,
            code_hash=hash_secret(code),
            expires_at=now + timedelta(minutes=ttl_minutes),
            created_at=now,
        )
        db.add(otp_row)
        db.commit()
        if otp_dispatcher is not None:
            otp_dispatcher(email, purpose, code)
        logger.info("OTP generated for purpose=%s (user_linked=%s)", purpose, bool(user_id))

    @router.post(
        "/register",
        response_model=AuthTokenResponse,
        status_code=status.HTTP_201_CREATED,
    )
    def register(
        payload: RegisterRequest,
        db: Session = Depends(get_db),
    ) -> JSONResponse:
        existing = db.scalar(select(UserORM).where(UserORM.email == payload.email))
        if existing is not None:
            return JSONResponse(
                status_code=status.HTTP_409_CONFLICT,
                content=ErrorResponse(
                    code="EMAIL_EXISTS",
                    message="An account with this email address already exists.",
                ).model_dump(),
            )

        user = UserORM(
            id=f"usr_{uuid.uuid4().hex[:12]}",
            name=payload.full_name or payload.name or "FixWise User",
            email=payload.email,
            password_hash=hash_secret(payload.password),
            role="Field Technician",
            account_status="active",
        )
        db.add(user)
        db.commit()
        db.refresh(user)

        token_response = _issue_token_payload(
            user=user,
            settings=settings,
            message="Account created successfully.",
        )
        return JSONResponse(
            status_code=status.HTTP_201_CREATED,
            content=token_response.model_dump(mode="json"),
        )

    @router.post("/login", response_model=AuthTokenResponse)
    def login(
        payload: LoginRequest,
        db: Session = Depends(get_db),
    ) -> JSONResponse:
        user = db.scalar(select(UserORM).where(UserORM.email == payload.email))
        if user is None or not verify_secret(payload.password, user.password_hash):
            return JSONResponse(
                status_code=status.HTTP_401_UNAUTHORIZED,
                content=ErrorResponse(
                    code="INVALID_CREDENTIALS",
                    message="Invalid email or password.",
                ).model_dump(),
            )

        if user.account_status != "active":
            return JSONResponse(
                status_code=status.HTTP_403_FORBIDDEN,
                content=ErrorResponse(
                    code="ACCOUNT_INACTIVE",
                    message=f"Account is not active (status: {user.account_status}).",
                ).model_dump(),
            )

        token_response = _issue_token_payload(user=user, settings=settings)
        return JSONResponse(
            status_code=status.HTTP_200_OK,
            content=token_response.model_dump(mode="json"),
        )

    @router.post("/refresh")
    def refresh_session(
        payload: RefreshTokenRequest,
        db: Session = Depends(get_db),
    ) -> JSONResponse:
        claims = decode_token(
            payload.refresh_token,
            settings,
            expected_type="refresh",
        )
        jti = claims.get("jti")
        if jti and db.get(RevokedTokenORM, jti) is not None:
            return JSONResponse(
                status_code=status.HTTP_401_UNAUTHORIZED,
                content=ErrorResponse(
                    code="TOKEN_REVOKED",
                    message="Refresh token has been revoked. Please sign in again.",
                ).model_dump(),
            )

        user_id = claims.get("sub")
        user = db.get(UserORM, user_id) if user_id else None
        if user is None or user.account_status != "active":
            return JSONResponse(
                status_code=status.HTTP_401_UNAUTHORIZED,
                content=ErrorResponse(
                    code="UNAUTHORIZED",
                    message="Session is no longer valid.",
                ).model_dump(),
            )

        # Rotate refresh token by revoking the consumed jti.
        if jti:
            db.add(RevokedTokenORM(jti=jti, user_id=user.id))
            db.commit()

        token_response = _issue_token_payload(user=user, settings=settings)
        return JSONResponse(
            status_code=status.HTTP_200_OK,
            content=token_response.model_dump(mode="json"),
        )

    @router.post("/logout")
    def logout(
        payload: LogoutRequest = LogoutRequest(),
        credentials: HTTPAuthorizationCredentials | None = Depends(_bearer_optional),
        current_user: UserORM = Depends(get_current_user),
        db: Session = Depends(get_db),
    ) -> JSONResponse:
        if credentials and credentials.credentials:
            claims = decode_token(
                credentials.credentials,
                settings,
                expected_type="access",
            )
            access_jti = claims.get("jti")
            if access_jti and db.get(RevokedTokenORM, access_jti) is None:
                db.add(RevokedTokenORM(jti=access_jti, user_id=current_user.id))

        if payload.refresh_token:
            try:
                refresh_claims = decode_token(
                    payload.refresh_token,
                    settings,
                    expected_type="refresh",
                )
                refresh_jti = refresh_claims.get("jti")
                if (
                    refresh_jti
                    and refresh_claims.get("sub") == current_user.id
                    and db.get(RevokedTokenORM, refresh_jti) is None
                ):
                    db.add(RevokedTokenORM(jti=refresh_jti, user_id=current_user.id))
            except HTTPException:
                # Ignore already expired/invalid refresh tokens on logout.
                pass

        db.commit()
        return JSONResponse(
            status_code=status.HTTP_200_OK,
            content={"status": "logged_out", "message": "Session terminated safely."},
        )

    @router.get("/me")
    def get_profile(
        current_user: UserORM = Depends(get_current_user),
    ) -> JSONResponse:
        return JSONResponse(
            status_code=status.HTTP_200_OK,
            content={"user": _serialize_user(current_user).model_dump(mode="json")},
        )

    @router.patch("/me")
    def update_profile(
        payload: ProfileUpdateRequest,
        current_user: UserORM = Depends(get_current_user),
        db: Session = Depends(get_db),
    ) -> JSONResponse:
        if payload.role is not None:
            requested_role = payload.role.strip()
            if (
                requested_role.lower() in _PRIVILEGED_ROLES
                and current_user.role.lower() != requested_role.lower()
            ):
                return JSONResponse(
                    status_code=status.HTTP_403_FORBIDDEN,
                    content=ErrorResponse(
                        code="ROLE_ESCALATION_FORBIDDEN",
                        message="Privileged account roles cannot be self-assigned.",
                    ).model_dump(),
                )
            current_user.role = requested_role

        current_user.name = payload.full_name
        db.add(current_user)
        db.commit()
        db.refresh(current_user)

        return JSONResponse(
            status_code=status.HTTP_200_OK,
            content={
                "user": _serialize_user(current_user).model_dump(mode="json"),
                "message": "Profile updated successfully.",
            },
        )

    @router.post("/password/change")
    def change_password(
        payload: ChangePasswordRequest,
        current_user: UserORM = Depends(get_current_user),
        db: Session = Depends(get_db),
    ) -> JSONResponse:
        if not verify_secret(payload.current_password, current_user.password_hash):
            return JSONResponse(
                status_code=status.HTTP_401_UNAUTHORIZED,
                content=ErrorResponse(
                    code="INVALID_CURRENT_PASSWORD",
                    message="Current password is incorrect.",
                ).model_dump(),
            )

        if payload.current_password == payload.new_password:
            return JSONResponse(
                status_code=422,
                content=ErrorResponse(
                    code="PASSWORD_UNCHANGED",
                    message="New password must be different from your current password.",
                ).model_dump(),
            )

        current_user.password_hash = hash_secret(payload.new_password)
        db.add(current_user)
        db.commit()
        return JSONResponse(
            status_code=status.HTTP_200_OK,
            content={"message": "Password updated successfully."},
        )

    @router.post("/otp/send")
    def send_otp(
        payload: OtpSendRequest,
        db: Session = Depends(get_db),
    ) -> JSONResponse:
        user = db.scalar(select(UserORM).where(UserORM.email == payload.email))
        _create_and_dispatch_otp(
            db,
            email=payload.email,
            purpose=payload.purpose,
            user_id=user.id if user else None,
        )
        return JSONResponse(
            status_code=status.HTTP_200_OK,
            content={
                "otp_sent": True,
                "message": f"A 6-digit verification code has been sent to {payload.email}.",
            },
        )

    @router.post("/otp/verify")
    def verify_otp(
        payload: OtpVerifyRequest,
        db: Session = Depends(get_db),
    ) -> JSONResponse:
        otp_row = db.scalar(
            select(OtpCodeORM)
            .where(
                OtpCodeORM.email == payload.email,
                OtpCodeORM.purpose == payload.purpose,
                OtpCodeORM.consumed_at.is_(None),
            )
            .order_by(OtpCodeORM.created_at.desc())
            .limit(1)
        )
        if otp_row is None:
            return JSONResponse(
                status_code=status.HTTP_400_BAD_REQUEST,
                content=ErrorResponse(
                    code="INVALID_OTP",
                    message="Invalid or already used verification code.",
                ).model_dump(),
            )

        now = datetime.now(timezone.utc)
        if now > _ensure_utc(otp_row.expires_at):
            return JSONResponse(
                status_code=status.HTTP_410_GONE,
                content=ErrorResponse(
                    code="OTP_EXPIRED",
                    message="This verification code has expired. Please request a new code.",
                ).model_dump(),
            )

        if not verify_secret(payload.code or "", otp_row.code_hash):
            return JSONResponse(
                status_code=status.HTTP_400_BAD_REQUEST,
                content=ErrorResponse(
                    code="INVALID_OTP",
                    message="Invalid verification code. Please check the 6-digit code and try again.",
                ).model_dump(),
            )

        otp_row.consumed_at = now
        db.add(otp_row)
        db.commit()

        user = db.scalar(select(UserORM).where(UserORM.email == payload.email))
        if user is not None and user.account_status == "active":
            token_response = _issue_token_payload(
                user=user,
                settings=settings,
                message="Email verified successfully.",
            )
            return JSONResponse(
                status_code=status.HTTP_200_OK,
                content=token_response.model_dump(mode="json"),
            )

        return JSONResponse(
            status_code=status.HTTP_200_OK,
            content={"verified": True, "message": "Email verified successfully."},
        )

    @router.post("/password/forgot")
    def forgot_password(
        payload: ForgotPasswordRequest,
        db: Session = Depends(get_db),
    ) -> JSONResponse:
        user = db.scalar(select(UserORM).where(UserORM.email == payload.email))
        if user is not None:
            _create_and_dispatch_otp(
                db,
                email=user.email,
                purpose="password_reset",
                user_id=user.id,
            )
        # Always return non-enumerating response to avoid leaking registered emails.
        return JSONResponse(
            status_code=status.HTTP_200_OK,
            content={
                "message": (
                    f"If an account exists for {payload.email}, "
                    "a 6-digit password reset code has been sent."
                )
            },
        )

    @router.post("/password/reset")
    def reset_password(
        payload: ResetPasswordRequest,
        db: Session = Depends(get_db),
    ) -> JSONResponse:
        otp_row = db.scalar(
            select(OtpCodeORM)
            .where(
                OtpCodeORM.email == payload.email,
                OtpCodeORM.purpose == "password_reset",
                OtpCodeORM.consumed_at.is_(None),
            )
            .order_by(OtpCodeORM.created_at.desc())
            .limit(1)
        )
        if otp_row is None:
            return JSONResponse(
                status_code=status.HTTP_400_BAD_REQUEST,
                content=ErrorResponse(
                    code="INVALID_OTP",
                    message="Invalid or already used password reset code.",
                ).model_dump(),
            )

        now = datetime.now(timezone.utc)
        if now > _ensure_utc(otp_row.expires_at):
            return JSONResponse(
                status_code=status.HTTP_410_GONE,
                content=ErrorResponse(
                    code="OTP_EXPIRED",
                    message="This password reset code has expired. Please request a new code.",
                ).model_dump(),
            )

        if not verify_secret(payload.code or "", otp_row.code_hash):
            return JSONResponse(
                status_code=status.HTTP_400_BAD_REQUEST,
                content=ErrorResponse(
                    code="INVALID_OTP",
                    message="Invalid password reset code.",
                ).model_dump(),
            )

        user = db.scalar(select(UserORM).where(UserORM.email == payload.email))
        if user is None:
            return JSONResponse(
                status_code=status.HTTP_400_BAD_REQUEST,
                content=ErrorResponse(
                    code="INVALID_OTP",
                    message="Invalid password reset request.",
                ).model_dump(),
            )

        user.password_hash = hash_secret(payload.new_password)
        otp_row.consumed_at = now
        db.add(user)
        db.add(otp_row)
        db.commit()

        return JSONResponse(
            status_code=status.HTTP_200_OK,
            content={
                "message": "Your password has been reset successfully. You can now sign in."
            },
        )

    return router
