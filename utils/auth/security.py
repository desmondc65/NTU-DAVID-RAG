"""Password hashing, CSRF tokens, cookie helpers.

Uses Argon2id. The verifier silently re-hashes on login when parameters in
config have been bumped, so upgrading costs doesn't require a password reset.
"""
from __future__ import annotations

import hmac
import secrets
from datetime import datetime, timedelta, timezone
from typing import Optional

from argon2 import PasswordHasher
from argon2.exceptions import InvalidHash, VerifyMismatchError

from .config import get_config


def _hasher() -> PasswordHasher:
    cfg = get_config()
    return PasswordHasher(
        time_cost=cfg.argon2_time_cost,
        memory_cost=cfg.argon2_memory_cost,
        parallelism=cfg.argon2_parallelism,
    )


def hash_password(password: str) -> str:
    return _hasher().hash(password)


def verify_password(stored_hash: str, password: str) -> tuple[bool, Optional[str]]:
    """Return ``(ok, new_hash_or_none)``.

    ``new_hash_or_none`` is a freshly computed hash when the stored one was
    valid but used stale parameters — callers should persist it.
    """
    ph = _hasher()
    try:
        ph.verify(stored_hash, password)
    except (VerifyMismatchError, InvalidHash):
        return False, None
    if ph.check_needs_rehash(stored_hash):
        return True, ph.hash(password)
    return True, None


def generate_session_id() -> str:
    return secrets.token_urlsafe(32)


def generate_csrf_token() -> str:
    return secrets.token_urlsafe(32)


def constant_time_equals(a: str, b: str) -> bool:
    return hmac.compare_digest(a.encode("utf-8"), b.encode("utf-8"))


def session_expires_at(now: Optional[datetime] = None) -> datetime:
    now = now or datetime.now(tz=timezone.utc)
    return now + timedelta(days=get_config().session_ttl_days)


def validate_password_strength(password: str) -> Optional[str]:
    """Return an error string if the password is unacceptable, else None."""
    if not password:
        return "Password is required."
    return None
