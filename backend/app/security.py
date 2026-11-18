"""Security primitives for FixWise:
- Salted memory-hard scrypt password hashing (OWASP recommended)
- Signed HS256 JWT access & refresh tokens with jti revocation support
- FastAPI current-user and role-based authorization dependencies
- Sliding-window per-client rate limiter middleware
"""

from __future__ import annotations

import base64
import hashlib
import hmac
import secrets
import time
import uuid
from collections import defaultdict, deque
from datetime import datetime, timedelta, timezone

import jwt
from fastapi import Depends, HTTPException, Request, status
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer
from sqlalchemy.orm import Session

from .config import Settings
from .db_models import RevokedTokenORM, UserORM

_SCRYPT_N = 16384
_SCRYPT_R = 8
_SCRYPT_P = 1
_SCRYPT_DKLEN = 32
_JWT_ALGORITHM = "HS256"

_bearer_scheme = HTTPBearer(auto_error=False)


def hash_secret(plain: str) -> str:
    """Hashes a password or OTP code using a random 16-byte salt and scrypt."""
    salt = secrets.token_bytes(16)
    derived = hashlib.scrypt(
        plain.encode("utf-8"),
        salt=salt,
        n=_SCRYPT_N,
        r=_SCRYPT_R,
        p=_SCRYPT_P,
        dklen=_SCRYPT_DKLEN,
    )
    salt_b64 = base64.urlsafe_b64encode(salt).decode("ascii")
    hash_b64 = base64.urlsafe_b64encode(derived).decode("ascii")
    return f"scrypt${_SCRYPT_N}${_SCRYPT_R}${_SCRYPT_P}${salt_b64}${hash_b64}"


def verify_secret(plain: str, encoded_hash: str) -> bool:
    """Verifies a plaintext password or OTP against a stored scrypt hash in constant time."""
    try:
        parts = encoded_hash.split("$")
        if len(parts) != 6 or parts[0] != "scrypt":
            return False
        n, r, p = int(parts[1]), int(parts[2]), int(parts[3])
        salt = base64.urlsafe_b64decode(parts[4].encode("ascii"))
        expected = base64.urlsafe_b64decode(parts[5].encode("ascii"))
        actual = hashlib.scrypt(
            plain.encode("utf-8"),
            salt=salt,
            n=n,
            r=r,
            p=p,
            dklen=len(expected),
        )
        return hmac.compare_digest(actual, expected)
    except Exception:
        return False


def generate_six_digit_otp() -> str:
    """Generates a cryptographically secure 6-digit OTP code on the server."""
    return f"{secrets.randbelow(1_000_000):06d}"


def create_access_token(
    *,
    user: UserORM,
    settings: Settings,
) -> tuple[str, datetime]:
    now = datetime.now(timezone.utc)
    expires_at = now + timedelta(minutes=settings.access_token_minutes)
    payload = {
        "sub": user.id,
        "email": user.email,
        "role": user.role,
        "type": "access",
        "jti": uuid.uuid4().hex,
        "iat": int(now.timestamp()),
        "exp": int(expires_at.timestamp()),
    }
    token = jwt.encode(payload, settings.jwt_secret, algorithm=_JWT_ALGORITHM)
    return token, expires_at


def create_refresh_token(
    *,
    user: UserORM,
    settings: Settings,
) -> str:
    now = datetime.now(timezone.utc)
    expires_at = now + timedelta(days=settings.refresh_token_days)
    payload = {
        "sub": user.id,
        "type": "refresh",
        "jti": uuid.uuid4().hex,
        "iat": int(now.timestamp()),
        "exp": int(expires_at.timestamp()),
    }
    return jwt.encode(payload, settings.jwt_secret, algorithm=_JWT_ALGORITHM)


def decode_token(token: str, settings: Settings, *, expected_type: str) -> dict:
    try:
        payload = jwt.decode(
            token,
            settings.jwt_secret,
            algorithms=[_JWT_ALGORITHM],
        )
    except jwt.ExpiredSignatureError as exc:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Authentication token has expired.",
        ) from exc
    except jwt.InvalidTokenError as exc:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid authentication token.",
        ) from exc

    if payload.get("type") != expected_type:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail=f"Expected a {expected_type} token.",
        )
    return payload


def build_current_user_dependency(get_db, settings: Settings):
    """Creates a FastAPI dependency that strictly verifies signed JWT tokens
    and returns the authenticated active [UserORM] record.
    """

    def _get_current_user(
        credentials: HTTPAuthorizationCredentials | None = Depends(_bearer_scheme),
        db: Session = Depends(get_db),
    ) -> UserORM:
        if credentials is None or not credentials.credentials:
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="Authentication credentials were not provided.",
            )

        payload = decode_token(
            credentials.credentials,
            settings,
            expected_type="access",
        )
        jti = payload.get("jti")
        if jti and db.get(RevokedTokenORM, jti) is not None:
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="Session token has been revoked.",
            )

        user_id = payload.get("sub")
        user = db.get(UserORM, user_id) if user_id else None
        if user is None:
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="Authenticated user account no longer exists.",
            )
        if user.account_status != "active":
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail=f"Account is not active (status: {user.account_status}).",
            )
        return user

    return _get_current_user


def require_roles(get_current_user, allowed_roles: set[str]):
    """Role-based authorization dependency."""

    def _check_role(user: UserORM = Depends(get_current_user)) -> UserORM:
        if user.role.lower() not in {r.lower() for r in allowed_roles}:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="Insufficient permissions for this resource.",
            )
        return user

    return _check_role


class SlidingWindowRateLimiter:
    """In-memory sliding-window per-IP rate limiter for API protection."""

    def __init__(self, max_requests: int, window_seconds: int) -> None:
        self._max_requests = max_requests
        self._window_seconds = window_seconds
        self._hits: dict[str, deque[float]] = defaultdict(deque)

    def allow(self, client_key: str) -> bool:
        now = time.monotonic()
        cutoff = now - self._window_seconds
        bucket = self._hits[client_key]
        while bucket and bucket[0] < cutoff:
            bucket.popleft()
        if len(bucket) >= self._max_requests:
            return False
        bucket.append(now)
        return True

    def client_key_from_request(self, request: Request) -> str:
        forwarded = request.headers.get("x-forwarded-for")
        if forwarded:
            return forwarded.split(",")[0].strip()
        return request.client.host if request.client else "unknown"
