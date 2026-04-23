"""Runtime configuration for the shared auth module.

All knobs are env-driven so both Flask apps and Alembic read the same values.
Import ``get_config()`` lazily (inside functions) to let ``.env`` loaders run
first.
"""
from __future__ import annotations

import os
import secrets
from dataclasses import dataclass
from functools import lru_cache


@dataclass(frozen=True)
class AuthConfig:
    db_url: str
    session_secret: str
    session_cookie_name: str
    session_cookie_secure: bool
    session_ttl_days: int
    csrf_cookie_name: str
    app_scope: str
    allow_registration: bool
    password_min_length: int
    argon2_time_cost: int
    argon2_memory_cost: int
    argon2_parallelism: int


def _as_bool(raw: str | None, default: bool) -> bool:
    if raw is None:
        return default
    return raw.strip().lower() in {"1", "true", "yes", "on"}


@lru_cache(maxsize=1)
def get_config() -> AuthConfig:
    db_url = os.environ.get("AUTH_DB_URL")
    if not db_url:
        raise RuntimeError(
            "AUTH_DB_URL is not set. The auth module needs a PostgreSQL URL "
            "of the form postgresql+psycopg://user:pass@host:5432/dbname."
        )

    session_secret = os.environ.get("SESSION_SECRET", "")
    if len(session_secret) < 32:
        # Refuse silent weak secrets. In dev, generate one and print a warning
        # so at least the app starts — operators see the line in logs.
        generated = secrets.token_hex(32)
        print(
            "[auth] WARNING: SESSION_SECRET missing or <32 chars. "
            "Using an ephemeral value for this process only. "
            "Set SESSION_SECRET in .env for persistence across restarts."
        )
        session_secret = generated

    scope = os.environ.get("APP_SCOPE", "rag").strip().lower()
    if scope not in {"rag", "graphrag"}:
        raise RuntimeError(f"APP_SCOPE must be 'rag' or 'graphrag', got {scope!r}")

    return AuthConfig(
        db_url=db_url,
        session_secret=session_secret,
        session_cookie_name=os.environ.get("SESSION_COOKIE_NAME", "session"),
        session_cookie_secure=_as_bool(os.environ.get("SESSION_COOKIE_SECURE"), False),
        session_ttl_days=int(os.environ.get("SESSION_TTL_DAYS", "30")),
        csrf_cookie_name=os.environ.get("CSRF_COOKIE_NAME", "csrf_token"),
        app_scope=scope,
        allow_registration=_as_bool(os.environ.get("ALLOW_REGISTRATION"), True),
        password_min_length=int(os.environ.get("PASSWORD_MIN_LENGTH", "12")),
        argon2_time_cost=int(os.environ.get("ARGON2_TIME_COST", "3")),
        argon2_memory_cost=int(os.environ.get("ARGON2_MEMORY_COST", str(64 * 1024))),
        argon2_parallelism=int(os.environ.get("ARGON2_PARALLELISM", "4")),
    )
