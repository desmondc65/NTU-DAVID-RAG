"""``/api/auth/*`` routes — registered identically by both Flask apps."""
from __future__ import annotations

import logging
from typing import Any

from flask import Blueprint, jsonify, make_response, request
from sqlalchemy.exc import IntegrityError

from . import audit
from .audit import record_event
from .config import get_config
from .db import get_session
from .decorators import (
    apply_session_cookies,
    clear_session_cookies,
    csrf_protect,
    current_session,
    current_user,
    login_required,
)
from .models import AuthSession, User
from .rate_limit import LOGIN_PER_EMAIL, LOGIN_PER_IP, REGISTER_PER_IP
from .repos import SessionRepo, UserRepo
from .security import (
    hash_password,
    validate_password_strength,
    verify_password,
)

logger = logging.getLogger(__name__)

auth_bp = Blueprint("auth", __name__, url_prefix="/api/auth")

_MAX_USER_ID_LEN = 254
_MAX_DISPLAY_NAME_LEN = 80


def _user_payload(user: User) -> dict[str, Any]:
    return {
        "id": str(user.id),
        "email": user.email,
        "display_name": user.display_name,
    }


def _request_ip() -> str | None:
    # X-Forwarded-For is set by the nginx proxy; take the leftmost entry.
    xff = request.headers.get("X-Forwarded-For")
    if xff:
        return xff.split(",")[0].strip() or None
    return request.remote_addr


def _validate_email(raw: Any) -> tuple[str | None, str | None]:
    # Field is called "email" on the wire for back-compat, but any non-empty
    # string is accepted as a user identifier.
    if not isinstance(raw, str):
        return None, "user id must be a string"
    user_id = raw.strip().lower()
    if not user_id or len(user_id) > _MAX_USER_ID_LEN:
        return None, "invalid user id"
    return user_id, None


@auth_bp.post("/register")
def register():
    cfg = get_config()
    if not cfg.allow_registration:
        return jsonify({"error": "registration disabled"}), 403

    ip = _request_ip() or "unknown"
    if not REGISTER_PER_IP.hit(f"ip:{ip}"):
        return jsonify({"error": "too many attempts, try again later"}), 429

    body = request.get_json(silent=True) or {}
    email, err = _validate_email(body.get("email"))
    if err:
        return jsonify({"error": err}), 400
    password = body.get("password")
    if not isinstance(password, str):
        return jsonify({"error": "password must be a string"}), 400
    if (msg := validate_password_strength(password)) is not None:
        return jsonify({"error": msg}), 400

    display_name = body.get("display_name")
    if display_name is not None:
        if not isinstance(display_name, str) or len(display_name) > _MAX_DISPLAY_NAME_LEN:
            return jsonify({"error": "invalid display_name"}), 400
        display_name = display_name.strip() or None

    db = get_session()
    users = UserRepo(db)
    if users.get_by_email(email) is not None:
        return jsonify({"error": "user id already registered"}), 409
    try:
        user = users.create(email=email, password=password, display_name=display_name)
    except IntegrityError:
        db.rollback()
        return jsonify({"error": "user id already registered"}), 409

    sessions = SessionRepo(db)
    session_row, raw_id = sessions.create(
        user_id=user.id,
        ip=_request_ip(),
        user_agent=request.headers.get("User-Agent"),
    )
    record_event(
        db,
        audit.REGISTERED,
        user_id=user.id,
        ip=_request_ip(),
        user_agent=request.headers.get("User-Agent"),
    )
    db.commit()

    resp = make_response(jsonify({"user": _user_payload(user)}), 201)
    apply_session_cookies(resp, raw_id, session_row.csrf_token)
    return resp


@auth_bp.post("/login")
def login():
    ip = _request_ip() or "unknown"
    if not LOGIN_PER_IP.hit(f"ip:{ip}"):
        return jsonify({"error": "too many attempts, try again later"}), 429

    body = request.get_json(silent=True) or {}
    email, err = _validate_email(body.get("email"))
    password = body.get("password")
    if err or not isinstance(password, str) or not password:
        # Generic message so we don't help enumerate accounts.
        return jsonify({"error": "invalid user id or password"}), 401

    if not LOGIN_PER_EMAIL.hit(f"email:{email}"):
        return jsonify({"error": "too many attempts, try again later"}), 429

    db = get_session()
    users = UserRepo(db)
    user = users.get_by_email(email)

    ip = _request_ip()
    ua = request.headers.get("User-Agent")

    if user is None or not user.is_active:
        record_event(
            db,
            audit.LOGIN_FAIL,
            user_id=user.id if user is not None else None,
            ip=ip,
            user_agent=ua,
            metadata={"email": email, "reason": "unknown_or_inactive"},
        )
        db.commit()
        return jsonify({"error": "invalid user id or password"}), 401

    ok, rehash = verify_password(user.password_hash, password)
    if not ok:
        record_event(
            db,
            audit.LOGIN_FAIL,
            user_id=user.id,
            ip=ip,
            user_agent=ua,
            metadata={"email": email, "reason": "bad_password"},
        )
        db.commit()
        return jsonify({"error": "invalid user id or password"}), 401
    if rehash is not None:
        users.update_password_hash(user, rehash)

    sessions = SessionRepo(db)
    session_row, raw_id = sessions.create(
        user_id=user.id,
        ip=ip,
        user_agent=ua,
    )
    record_event(db, audit.LOGIN_OK, user_id=user.id, ip=ip, user_agent=ua)
    db.commit()

    resp = make_response(jsonify({"user": _user_payload(user)}), 200)
    apply_session_cookies(resp, raw_id, session_row.csrf_token)
    return resp


@auth_bp.post("/logout")
@login_required
@csrf_protect
def logout():
    db = get_session()
    session = current_session()
    user = current_user()
    if session is not None:
        SessionRepo(db).revoke(session)
        record_event(
            db,
            audit.LOGOUT,
            user_id=user.id if user else None,
            ip=_request_ip(),
            user_agent=request.headers.get("User-Agent"),
        )
        db.commit()
    resp = make_response("", 204)
    clear_session_cookies(resp)
    return resp


@auth_bp.get("/me")
def me():
    user = current_user()
    if user is None:
        return jsonify({"error": "authentication required"}), 401
    return jsonify({"user": _user_payload(user)})


# ── Password change ──────────────────────────────────────────────────

@auth_bp.post("/password/change")
@login_required
@csrf_protect
def change_password():
    body = request.get_json(silent=True) or {}
    old_pw = body.get("old_password")
    new_pw = body.get("new_password")
    if not isinstance(old_pw, str) or not isinstance(new_pw, str):
        return jsonify({"error": "old_password and new_password are required"}), 400
    if (msg := validate_password_strength(new_pw)) is not None:
        return jsonify({"error": msg}), 400
    if old_pw == new_pw:
        return jsonify({"error": "new password must differ from the current one"}), 400

    user = current_user()
    session = current_session()
    assert user is not None and session is not None

    db = get_session()
    ok, _ = verify_password(user.password_hash, old_pw)
    if not ok:
        record_event(
            db,
            audit.LOGIN_FAIL,
            user_id=user.id,
            ip=_request_ip(),
            user_agent=request.headers.get("User-Agent"),
            metadata={"reason": "bad_password_on_change"},
        )
        db.commit()
        return jsonify({"error": "current password is incorrect"}), 401

    # Update hash, revoke every OTHER session (current stays alive), audit.
    UserRepo(db).update_password_hash(user, hash_password(new_pw))
    revoked = SessionRepo(db).revoke_others_for_user(user.id, session.id)
    record_event(
        db,
        audit.PASSWORD_CHANGED,
        user_id=user.id,
        ip=_request_ip(),
        user_agent=request.headers.get("User-Agent"),
        metadata={"other_sessions_revoked": revoked},
    )
    db.commit()
    return jsonify({"other_sessions_revoked": revoked})


# ── Active sessions ──────────────────────────────────────────────────

def _session_payload(s: AuthSession, *, current: bool) -> dict[str, Any]:
    return {
        "id": str(s.id),
        "created_at": s.created_at.isoformat() if s.created_at else None,
        "last_seen_at": s.last_seen_at.isoformat() if s.last_seen_at else None,
        "expires_at": s.expires_at.isoformat() if s.expires_at else None,
        "ip": str(s.ip) if s.ip else None,
        "user_agent": s.user_agent,
        "current": current,
    }


@auth_bp.get("/sessions")
@login_required
def list_sessions():
    user = current_user()
    cur = current_session()
    assert user is not None and cur is not None
    db = get_session()
    rows = SessionRepo(db).list_active_for_user(user.id)
    return jsonify([_session_payload(s, current=(s.id == cur.id)) for s in rows])


@auth_bp.delete("/sessions/<sid>")
@login_required
@csrf_protect
def revoke_session(sid: str):
    import uuid as _uuid
    try:
        target_id = _uuid.UUID(sid)
    except (ValueError, TypeError):
        return jsonify({"error": "not found"}), 404

    user = current_user()
    cur = current_session()
    assert user is not None and cur is not None

    db = get_session()
    target = SessionRepo(db).get_by_id_for_user(target_id, user.id)
    if target is None:
        return jsonify({"error": "not found"}), 404
    if target.revoked_at is not None:
        # Idempotent: already revoked.
        return "", 204

    SessionRepo(db).revoke(target)
    record_event(
        db,
        audit.SESSION_REVOKED,
        user_id=user.id,
        ip=_request_ip(),
        user_agent=request.headers.get("User-Agent"),
        metadata={
            "revoked_session_id": str(target.id),
            "self": target.id == cur.id,
        },
    )
    db.commit()

    # If the user killed their own session, clear their cookies too.
    if target.id == cur.id:
        resp = make_response("", 204)
        clear_session_cookies(resp)
        return resp
    return "", 204


@auth_bp.post("/sessions/revoke-others")
@login_required
@csrf_protect
def revoke_other_sessions():
    user = current_user()
    cur = current_session()
    assert user is not None and cur is not None

    db = get_session()
    revoked = SessionRepo(db).revoke_others_for_user(user.id, cur.id)
    record_event(
        db,
        audit.SESSION_REVOKED_OTHERS,
        user_id=user.id,
        ip=_request_ip(),
        user_agent=request.headers.get("User-Agent"),
        metadata={"revoked": revoked},
    )
    db.commit()
    return jsonify({"revoked": revoked})
