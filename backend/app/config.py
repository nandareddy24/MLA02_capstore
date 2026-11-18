"""Environment-driven backend settings and secure secret management."""

from __future__ import annotations

import os
import secrets
from dataclasses import dataclass
from pathlib import Path

BACKEND_ROOT = Path(__file__).resolve().parent.parent
REPO_ROOT = BACKEND_ROOT.parent


@dataclass(frozen=True)
class Settings:
    env: str
    database_url: str
    jwt_secret: str
    access_token_minutes: int
    refresh_token_days: int
    cors_origins: list[str]
    enforce_https: bool
    rate_limit_requests: int
    rate_limit_window_seconds: int
    artifact_path: Path
    metadata_path: Path
    kb_path: Path
    severity_rules_path: Path
    catalog_path: Path

    @property
    def is_production(self) -> bool:
        return self.env.lower() == "production"


def load_settings(
    *,
    env: str | None = None,
    database_url: str | None = None,
    jwt_secret: str | None = None,
    cors_origins: list[str] | None = None,
    enforce_https: bool | None = None,
    rate_limit_requests: int | None = None,
    rate_limit_window_seconds: int | None = None,
    artifact_path: Path | None = None,
    metadata_path: Path | None = None,
    kb_path: Path | None = None,
    severity_rules_path: Path | None = None,
    catalog_path: Path | None = None,
) -> Settings:
    resolved_env = (env or os.getenv("FIXWISE_ENV", "development")).strip().lower()
    is_prod = resolved_env == "production"

    resolved_secret = jwt_secret or os.getenv("FIXWISE_JWT_SECRET", "")
    if not resolved_secret:
        if is_prod:
            raise RuntimeError(
                "FIXWISE_JWT_SECRET must be set via environment/secret manager in production."
            )
        # Ephemeral random secret for local development only (never hardcoded).
        resolved_secret = secrets.token_urlsafe(48)
    elif is_prod and len(resolved_secret) < 32:
        raise RuntimeError(
            "FIXWISE_JWT_SECRET must be at least 32 characters in production."
        )

    default_db_path = BACKEND_ROOT / "data" / "fixwise_dev.db"
    default_db_path.parent.mkdir(parents=True, exist_ok=True)
    resolved_db_url = database_url or os.getenv(
        "FIXWISE_DATABASE_URL",
        f"sqlite:///{default_db_path.as_posix()}",
    )
    if is_prod and resolved_db_url.startswith("sqlite:"):
        raise RuntimeError(
            "Production deployment requires MySQL (FIXWISE_DATABASE_URL=mysql+pymysql://...)."
        )

    raw_origins = os.getenv(
        "FIXWISE_CORS_ORIGINS",
        "http://localhost:3000,http://127.0.0.1:3000",
    )
    resolved_origins = (
        cors_origins
        if cors_origins is not None
        else [o.strip() for o in raw_origins.split(",") if o.strip()]
    )
    if is_prod and "*" in resolved_origins:
        raise RuntimeError("Wildcard CORS ('*') is forbidden in production.")

    resolved_https = (
        enforce_https
        if enforce_https is not None
        else (os.getenv("FIXWISE_ENFORCE_HTTPS", "false").lower() == "true" or is_prod)
    )

    return Settings(
        env=resolved_env,
        database_url=resolved_db_url,
        jwt_secret=resolved_secret,
        access_token_minutes=int(os.getenv("FIXWISE_ACCESS_TOKEN_MINUTES", "60")),
        refresh_token_days=int(os.getenv("FIXWISE_REFRESH_TOKEN_DAYS", "14")),
        cors_origins=resolved_origins,
        enforce_https=resolved_https,
        rate_limit_requests=(
            rate_limit_requests
            if rate_limit_requests is not None
            else int(os.getenv("FIXWISE_RATE_LIMIT_REQUESTS", "120"))
        ),
        rate_limit_window_seconds=(
            rate_limit_window_seconds
            if rate_limit_window_seconds is not None
            else int(os.getenv("FIXWISE_RATE_LIMIT_WINDOW_SECONDS", "60"))
        ),
        artifact_path=artifact_path or (BACKEND_ROOT / "artifacts" / "fixwise_model.joblib"),
        metadata_path=metadata_path or (BACKEND_ROOT / "artifacts" / "model_metadata.json"),
        kb_path=kb_path or (BACKEND_ROOT / "data" / "knowledge_base.json"),
        severity_rules_path=severity_rules_path
        or (BACKEND_ROOT / "data" / "severity_rules.json"),
        catalog_path=catalog_path
        or (REPO_ROOT / "assets" / "data" / "diagnostic_catalog.json"),
    )
