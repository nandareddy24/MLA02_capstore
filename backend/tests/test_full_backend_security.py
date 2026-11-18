"""Comprehensive security, authentication, ORM, RBAC, rate-limiting,
HTTPS enforcement, and production-guard tests for FixWise backend.
"""

from __future__ import annotations

from datetime import datetime, timedelta, timezone
from pathlib import Path

import pytest
from fastapi.testclient import TestClient
from sqlalchemy import select

from app.config import load_settings
from app.db_models import OtpCodeORM, UserORM
from app.main import create_app


def test_registration_login_refresh_logout_and_revocation(tmp_path: Path):
    app = create_app(
        artifact_path=tmp_path / "missing.joblib",
        metadata_path=tmp_path / "missing.json",
        database_url=f"sqlite:///{(tmp_path / 'sec.db').as_posix()}",
    )
    client = TestClient(app)

    # Weak password rejected
    weak = client.post(
        "/api/v1/auth/register",
        json={
            "full_name": "Test User",
            "email": "user@fixwise.io",
            "password": "password",
            "accepted_terms": True,
        },
    )
    assert weak.status_code == 422

    # Strong registration succeeds and hashes password with salted scrypt
    reg = client.post(
        "/api/v1/auth/register",
        json={
            "full_name": "Nanda Reddy",
            "email": "Nanda@FixWise.io",
            "password": "StrongPassword!1",
            "accepted_terms": True,
        },
    )
    assert reg.status_code == 201
    reg_body = reg.json()
    assert reg_body["user"]["email"] == "nanda@fixwise.io"
    assert "password" not in reg_body["user"]
    assert "password_hash" not in reg_body["user"]

    with app.state.session_factory() as db:
        stored = db.scalar(select(UserORM).where(UserORM.email == "nanda@fixwise.io"))
        assert stored is not None
        assert stored.password_hash.startswith("scrypt$")
        assert "StrongPassword!1" not in stored.password_hash

    # Duplicate email returns 409
    dup = client.post(
        "/api/v1/auth/register",
        json={
            "full_name": "Nanda Copy",
            "email": "nanda@fixwise.io",
            "password": "StrongPassword!1",
            "accepted_terms": True,
        },
    )
    assert dup.status_code == 409
    assert dup.json()["code"] == "EMAIL_EXISTS"

    # Wrong password rejected
    bad_login = client.post(
        "/api/v1/auth/login",
        json={"email": "nanda@fixwise.io", "password": "WrongPassword!1"},
    )
    assert bad_login.status_code == 401

    # Valid login issues fresh tokens
    login = client.post(
        "/api/v1/auth/login",
        json={"email": "nanda@fixwise.io", "password": "StrongPassword!1"},
    )
    assert login.status_code == 200
    access_token = login.json()["access_token"]
    refresh_token = login.json()["refresh_token"]

    # Refresh rotates tokens and revokes the old refresh token
    refreshed = client.post("/api/v1/auth/refresh", json={"refresh_token": refresh_token})
    assert refreshed.status_code == 200
    new_access = refreshed.json()["access_token"]
    new_refresh = refreshed.json()["refresh_token"]

    # Reusing the rotated refresh token must fail
    reused = client.post("/api/v1/auth/refresh", json={"refresh_token": refresh_token})
    assert reused.status_code == 401

    # Logout revokes active access & refresh tokens
    logout = client.post(
        "/api/v1/auth/logout",
        headers={"Authorization": f"Bearer {new_access}"},
        json={"refresh_token": new_refresh},
    )
    assert logout.status_code == 200

    # Revoked access token is immediately rejected
    me_after_logout = client.get(
        "/api/v1/auth/me",
        headers={"Authorization": f"Bearer {new_access}"},
    )
    assert me_after_logout.status_code == 401
    # Original non-revoked access token still works until logged out
    assert (
        client.get("/api/v1/auth/me", headers={"Authorization": f"Bearer {access_token}"}).status_code
        == 200
    )


def test_otp_verification_expiry_and_password_reset_flow(tmp_path: Path):
    delivered: list[tuple[str, str, str]] = []

    def capture_otp(email: str, purpose: str, code: str) -> None:
        delivered.append((email, purpose, code))

    app = create_app(
        artifact_path=tmp_path / "missing.joblib",
        metadata_path=tmp_path / "missing.json",
        database_url=f"sqlite:///{(tmp_path / 'otp.db').as_posix()}",
        otp_dispatcher=capture_otp,
    )
    client = TestClient(app)

    client.post(
        "/api/v1/auth/register",
        json={
            "full_name": "OTP User",
            "email": "otp@fixwise.io",
            "password": "OldPassword!1",
            "accepted_terms": True,
        },
    )

    # Send OTP (raw code must NEVER be in HTTP response!)
    send_resp = client.post(
        "/api/v1/auth/otp/send",
        json={"email": "otp@fixwise.io", "purpose": "email_verification"},
    )
    assert send_resp.status_code == 200
    assert len(delivered) == 1
    code = delivered[-1][2]
    assert code not in send_resp.text

    # Wrong OTP rejected with 400 INVALID_OTP
    wrong = client.post(
        "/api/v1/auth/otp/verify",
        json={"email": "otp@fixwise.io", "code": "000000", "purpose": "email_verification"},
    )
    assert wrong.status_code == 400
    assert wrong.json()["code"] == "INVALID_OTP"

    # Correct OTP succeeds and marks OTP consumed (cannot be reused)
    ok = client.post(
        "/api/v1/auth/otp/verify",
        json={"email": "otp@fixwise.io", "code": code, "purpose": "email_verification"},
    )
    assert ok.status_code == 200
    reuse = client.post(
        "/api/v1/auth/otp/verify",
        json={"email": "otp@fixwise.io", "code": code, "purpose": "email_verification"},
    )
    assert reuse.status_code == 400

    # Expired OTP returns 410 OTP_EXPIRED
    client.post(
        "/api/v1/auth/otp/send",
        json={"email": "otp@fixwise.io", "purpose": "login"},
    )
    expired_code = delivered[-1][2]
    with app.state.session_factory() as db:
        row = db.scalar(
            select(OtpCodeORM)
            .where(OtpCodeORM.email == "otp@fixwise.io", OtpCodeORM.purpose == "login")
            .order_by(OtpCodeORM.created_at.desc())
        )
        assert row is not None
        row.expires_at = datetime.now(timezone.utc) - timedelta(minutes=1)
        db.commit()

    expired_resp = client.post(
        "/api/v1/auth/otp/verify",
        json={"email": "otp@fixwise.io", "code": expired_code, "purpose": "login"},
    )
    assert expired_resp.status_code == 410
    assert expired_resp.json()["code"] == "OTP_EXPIRED"

    # Forgot + reset password flow
    forgot = client.post("/api/v1/auth/password/forgot", json={"email": "otp@fixwise.io"})
    assert forgot.status_code == 200
    reset_code = delivered[-1][2]

    reset = client.post(
        "/api/v1/auth/password/reset",
        json={
            "email": "otp@fixwise.io",
            "code": reset_code,
            "new_password": "NewStrongPassword!2",
        },
    )
    assert reset.status_code == 200

    # Old password fails, new password succeeds
    assert (
        client.post(
            "/api/v1/auth/login",
            json={"email": "otp@fixwise.io", "password": "OldPassword!1"},
        ).status_code
        == 401
    )
    assert (
        client.post(
            "/api/v1/auth/login",
            json={"email": "otp@fixwise.io", "password": "NewStrongPassword!2"},
        ).status_code
        == 200
    )


def test_device_crud_profile_update_rbac_and_role_escalation_guard(tmp_path: Path):
    app = create_app(
        artifact_path=tmp_path / "missing.joblib",
        metadata_path=tmp_path / "missing.json",
        database_url=f"sqlite:///{(tmp_path / 'devices.db').as_posix()}",
    )
    client = TestClient(app)

    u1 = client.post(
        "/api/v1/auth/register",
        json={
            "full_name": "User One",
            "email": "u1@fixwise.io",
            "password": "StrongPassword!1",
            "accepted_terms": True,
        },
    ).json()
    u2 = client.post(
        "/api/v1/auth/register",
        json={
            "full_name": "User Two",
            "email": "u2@fixwise.io",
            "password": "StrongPassword!1",
            "accepted_terms": True,
        },
    ).json()
    h1 = {"Authorization": f"Bearer {u1['access_token']}"}
    h2 = {"Authorization": f"Bearer {u2['access_token']}"}

    # Device CRUD scoped strictly to owner
    created = client.post(
        "/api/v1/devices",
        headers=h1,
        json={
            "category": "laptop",
            "manufacturer": "Lenovo",
            "model": "ThinkPad T14",
            "device_age": "1–2 years",
        },
    )
    assert created.status_code == 201
    dev_id = created.json()["id"]

    # User 2 cannot view or delete User 1's device
    assert client.get(f"/api/v1/devices/{dev_id}", headers=h2).status_code == 404
    assert client.delete(f"/api/v1/devices/{dev_id}", headers=h2).status_code == 404

    # User 1 lists and deletes own device
    assert client.get("/api/v1/devices", headers=h1).json()["total"] == 1
    assert client.delete(f"/api/v1/devices/{dev_id}", headers=h1).status_code == 200
    assert client.get("/api/v1/devices", headers=h1).json()["total"] == 0

    # Profile update blocks privilege escalation to admin
    escalate = client.patch(
        "/api/v1/auth/me",
        headers=h1,
        json={"full_name": "User One", "role": "admin"},
    )
    assert escalate.status_code == 403

    # RBAC blocks non-admin from admin diagnostics summary
    assert client.get("/api/v1/admin/diagnostics/summary", headers=h1).status_code == 403

    # Promote user 1 server-side in DB and verify RBAC allows admin access
    with app.state.session_factory() as db:
        row = db.get(UserORM, u1["user"]["id"])
        assert row is not None
        row.role = "admin"
        db.commit()

    admin_resp = client.get("/api/v1/admin/diagnostics/summary", headers=h1)
    assert admin_resp.status_code == 200
    assert admin_resp.json()["total_users"] == 2


def test_rate_limiting_and_https_enforcement_and_production_config_guards(tmp_path: Path):
    # Rate limiting returns 429 after max_requests
    limited_app = create_app(
        artifact_path=tmp_path / "missing.joblib",
        metadata_path=tmp_path / "missing.json",
        database_url=f"sqlite:///{(tmp_path / 'rl.db').as_posix()}",
        rate_limit_requests=3,
        rate_limit_window_seconds=60,
    )
    rl_client = TestClient(limited_app)
    assert rl_client.get("/api/v1/health").status_code == 200
    assert rl_client.get("/api/v1/health").status_code == 200
    assert rl_client.get("/api/v1/health").status_code == 200
    fourth = rl_client.get("/api/v1/health")
    assert fourth.status_code == 429
    assert fourth.json()["code"] == "RATE_LIMITED"

    # HTTPS enforcement blocks plain HTTP requests when enabled
    https_app = create_app(
        artifact_path=tmp_path / "missing.joblib",
        metadata_path=tmp_path / "missing.json",
        database_url=f"sqlite:///{(tmp_path / 'https.db').as_posix()}",
        enforce_https=True,
    )
    https_client = TestClient(https_app)
    plain = https_client.get("/api/v1/catalog/devices")
    assert plain.status_code == 403
    assert plain.json()["code"] == "HTTPS_REQUIRED"

    forwarded_https = https_client.get(
        "/api/v1/catalog/devices",
        headers={"X-Forwarded-Proto": "https"},
    )
    assert forwarded_https.status_code == 200
    assert "Strict-Transport-Security" in forwarded_https.headers

    # Production configuration guards reject missing secrets, SQLite, and wildcard CORS
    with pytest.raises(RuntimeError, match="FIXWISE_JWT_SECRET"):
        load_settings(env="production", jwt_secret="")

    with pytest.raises(RuntimeError, match="MySQL"):
        load_settings(
            env="production",
            jwt_secret="a" * 40,
            database_url="sqlite:///local.db",
        )

    with pytest.raises(RuntimeError, match="Wildcard CORS"):
        load_settings(
            env="production",
            jwt_secret="a" * 40,
            database_url="mysql+pymysql://u:p@db.internal:3306/fixwise",
            cors_origins=["*"],
        )
