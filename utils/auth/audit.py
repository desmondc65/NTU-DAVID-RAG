"""Audit event logging.

``record_event`` is a fire-and-forget helper: it never raises back into the
calling handler, because an audit-log failure should not break a login. It
flushes (so the ID is assigned) but does not commit — callers control the
transaction boundary.
"""
from __future__ import annotations

import logging
import uuid
from typing import Any, Optional

from sqlalchemy.orm import Session

from .models import AuthEvent

logger = logging.getLogger(__name__)


# Canonical event-type names.
LOGIN_OK = "login_ok"
LOGIN_FAIL = "login_fail"
LOGOUT = "logout"
REGISTERED = "user_registered"
PASSWORD_CHANGED = "password_changed"
PASSWORD_RESET_ADMIN = "password_reset_admin"
SESSION_REVOKED = "session_revoked"
SESSION_REVOKED_OTHERS = "session_revoked_others"
ACCOUNT_DISABLED = "account_disabled"
ACCOUNT_ENABLED = "account_enabled"


def record_event(
    db: Session,
    event_type: str,
    *,
    user_id: Optional[uuid.UUID] = None,
    ip: Optional[str] = None,
    user_agent: Optional[str] = None,
    metadata: Optional[dict[str, Any]] = None,
) -> None:
    try:
        ev = AuthEvent(
            user_id=user_id,
            event_type=event_type,
            ip=ip,
            user_agent=user_agent,
            metadata_=metadata or None,
        )
        db.add(ev)
        db.flush()
    except Exception:
        # Never let audit failures break the main flow.
        logger.warning("Failed to record auth event %s", event_type, exc_info=True)
