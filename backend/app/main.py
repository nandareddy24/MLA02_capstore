"""Modular FastAPI application for FixWise Fault Diagnosis & Decision Support.

Security & Architecture Highlights:
- SQLAlchemy 2.0 ORM targeting MySQL 8 (mysql+pymysql://) in production
- Salted scrypt password & OTP hashing; signed HS256 JWT tokens with jti revocation
- Strict server-side authorization & RBAC (never trusting client identity headers)
- Sliding-window per-client rate limiting, restricted CORS, and HTTPS enforcement
- Clean structured JSON error responses that never leak secrets or stack traces
"""

from __future__ import annotations

import logging
import time
from pathlib import Path
from typing import Callable, Optional

from fastapi import FastAPI, HTTPException, Request, status
from fastapi.exceptions import RequestValidationError
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse

from .config import Settings, load_settings
from .database import Base, build_engine, create_session_factory, session_dependency
from .decision_support_service import DecisionSupportService
from .knowledge_base import FaultKnowledgeBase
from .model_registry import ModelRegistry
from .routes.auth_routes import build_auth_router
from .routes.device_routes import build_device_router
from .routes.diagnosis_routes import build_diagnosis_router
from .routes.feedback_routes import build_feedback_router
from .schemas import ErrorResponse
from .security import SlidingWindowRateLimiter, build_current_user_dependency
from .severity_rules import SeverityRuleEngine

if not logging.getLogger().handlers:
    logging.basicConfig(
        level=logging.INFO,
        format="%(asctime)s %(levelname)s [%(name)s] %(message)s",
    )

logger = logging.getLogger("fixwise.api")


def create_app(
    *,
    settings: Optional[Settings] = None,
    database_url: Optional[str] = None,
    artifact_path: Optional[Path] = None,
    metadata_path: Optional[Path] = None,
    catalog_path: Optional[Path] = None,
    kb_path: Optional[Path] = None,
    severity_rules_path: Optional[Path] = None,
    enforce_https: Optional[bool] = None,
    rate_limit_requests: Optional[int] = None,
    rate_limit_window_seconds: Optional[int] = None,
    otp_dispatcher: Optional[Callable[[str, str, str], None]] = None,
) -> FastAPI:
    active_settings = settings or load_settings(
        database_url=database_url,
        artifact_path=artifact_path,
        metadata_path=metadata_path,
        catalog_path=catalog_path,
        kb_path=kb_path,
        severity_rules_path=severity_rules_path,
        enforce_https=enforce_https,
        rate_limit_requests=rate_limit_requests,
        rate_limit_window_seconds=rate_limit_window_seconds,
    )

    app = FastAPI(
        title="FixWise Fault Diagnosis & Decision Support API",
        version="2.0.0",
        description=(
            "Secure, modular AI-Based Fault Diagnosis & Safety-Aware Decision Support Backend."
        ),
        docs_url=None if active_settings.is_production else "/docs",
        redoc_url=None if active_settings.is_production else "/redoc",
    )

    # Database engine & relational schema initialization
    engine = build_engine(active_settings.database_url)
    Base.metadata.create_all(bind=engine)
    session_factory = create_session_factory(engine)
    get_db = session_dependency(session_factory)
    get_current_user = build_current_user_dependency(get_db, active_settings)

    # Core domain engines
    registry = ModelRegistry(
        artifact_path=active_settings.artifact_path,
        metadata_path=active_settings.metadata_path,
    )
    severity_engine = SeverityRuleEngine(active_settings.severity_rules_path)
    knowledge_base = FaultKnowledgeBase(active_settings.kb_path, severity_engine)
    decision_support = DecisionSupportService(
        knowledge_base=knowledge_base,
        severity_engine=severity_engine,
    )
    rate_limiter = SlidingWindowRateLimiter(
        max_requests=active_settings.rate_limit_requests,
        window_seconds=active_settings.rate_limit_window_seconds,
    )

    # Expose initialized components on app.state for diagnostics & tests
    app.state.settings = active_settings
    app.state.engine = engine
    app.state.session_factory = session_factory
    app.state.model_registry = registry
    app.state.decision_support = decision_support
    app.state.knowledge_base = knowledge_base
    app.state.rate_limiter = rate_limiter

    # Restricted CORS policy
    app.add_middleware(
        CORSMiddleware,
        allow_origins=active_settings.cors_origins,
        allow_credentials=True,
        allow_methods=["GET", "POST", "PUT", "PATCH", "DELETE", "OPTIONS"],
        allow_headers=["Authorization", "Content-Type", "Accept"],
    )

    @app.middleware("http")
    async def security_and_rate_limit_middleware(request: Request, call_next):
        started = time.perf_counter()

        # 1. Enforce HTTPS in production / when FIXWISE_ENFORCE_HTTPS=true
        if active_settings.enforce_https and request.url.path != "/api/v1/health":
            forwarded_proto = request.headers.get("x-forwarded-proto", "").lower()
            is_https = request.url.scheme == "https" or forwarded_proto == "https"
            if not is_https:
                return JSONResponse(
                    status_code=status.HTTP_403_FORBIDDEN,
                    content=ErrorResponse(
                        code="HTTPS_REQUIRED",
                        message="HTTPS transport is required for all FixWise API requests.",
                    ).model_dump(),
                )

        # 2. Sliding-window rate limiting per client IP
        client_key = rate_limiter.client_key_from_request(request)
        if not rate_limiter.allow(client_key):
            logger.warning("Rate limit exceeded for client=%s path=%s", client_key, request.url.path)
            return JSONResponse(
                status_code=status.HTTP_429_TOO_MANY_REQUESTS,
                content=ErrorResponse(
                    code="RATE_LIMITED",
                    message="Too many requests. Please wait briefly before trying again.",
                ).model_dump(),
            )

        response = await call_next(request)

        # 3. Security headers on every response
        response.headers["X-Content-Type-Options"] = "nosniff"
        response.headers["X-Frame-Options"] = "DENY"
        response.headers["Referrer-Policy"] = "no-referrer"
        response.headers["Cache-Control"] = "no-store"
        if active_settings.enforce_https:
            response.headers["Strict-Transport-Security"] = (
                "max-age=63072000; includeSubDomains"
            )

        elapsed_ms = round((time.perf_counter() - started) * 1000.0, 2)
        logger.info(
            "%s %s -> %s (%.2fms)",
            request.method,
            request.url.path,
            response.status_code,
            elapsed_ms,
        )
        return response

    # Global structured error handlers (never leak tracebacks or credentials)
    @app.exception_handler(RequestValidationError)
    async def validation_exception_handler(_request: Request, exc: RequestValidationError):
        safe_errors = [
            {
                "field": ".".join(str(part) for part in err.get("loc", [])),
                "message": err.get("msg", "Invalid value."),
            }
            for err in exc.errors()
        ]
        first_msg = safe_errors[0]["message"] if safe_errors else "Input validation failed."
        return JSONResponse(
            status_code=422,
            content=ErrorResponse(
                code="VALIDATION_ERROR",
                message=first_msg,
                details={"errors": safe_errors},
            ).model_dump(),
        )

    @app.exception_handler(HTTPException)
    async def http_exception_handler(_request: Request, exc: HTTPException):
        code_map = {
            400: "BAD_REQUEST",
            401: "UNAUTHORIZED",
            403: "FORBIDDEN",
            404: "NOT_FOUND",
            409: "CONFLICT",
            410: "GONE",
            429: "RATE_LIMITED",
        }
        return JSONResponse(
            status_code=exc.status_code,
            content=ErrorResponse(
                code=code_map.get(exc.status_code, "HTTP_ERROR"),
                message=str(exc.detail),
            ).model_dump(),
        )

    @app.exception_handler(Exception)
    async def unhandled_exception_handler(_request: Request, _exc: Exception):
        logger.exception("Unhandled server exception")
        return JSONResponse(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            content=ErrorResponse(
                code="INTERNAL_SERVER_ERROR",
                message="An internal server error occurred. Please try again later.",
            ).model_dump(),
        )

    @app.get("/api/v1/health", tags=["system"])
    def health() -> dict:
        db_dialect = engine.dialect.name
        return {
            "status": "ok",
            "environment": active_settings.env,
            "database_backend": db_dialect,
            "model_loaded": registry.is_ready,
            "integration_status": "ready" if registry.is_ready else "pending",
            "model_version": registry.metadata.get("model_version"),
            "algorithm": registry.metadata.get("algorithm"),
            "reviewed_kb_records": len(knowledge_base.reviewed_records),
            "message": (
                "Trained model artifact loaded and verified."
                if registry.is_ready
                else registry.load_error
            ),
        }

    # Mount modular routers
    app.include_router(
        build_auth_router(
            get_db=get_db,
            get_current_user=get_current_user,
            settings=active_settings,
            otp_dispatcher=otp_dispatcher,
        )
    )
    app.include_router(
        build_device_router(
            get_db=get_db,
            get_current_user=get_current_user,
        )
    )
    app.include_router(
        build_diagnosis_router(
            get_db=get_db,
            get_current_user=get_current_user,
            registry=registry,
            decision_support=decision_support,
            catalog_path=active_settings.catalog_path,
        )
    )
    app.include_router(
        build_feedback_router(
            get_db=get_db,
            get_current_user=get_current_user,
        )
    )

    return app


app = create_app()
