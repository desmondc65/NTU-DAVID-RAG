"""``/api/auth/*`` routes — registered identically by both Flask apps."""
from __future__ import annotations

import logging
import re
from typing import Any

from flask import Blueprint, jsonify, make_response, request
from sqlalchemy.exc import IntegrityError

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
from .models import User
from .rate_limit import LOGIN_PER_EMAIL, LOGIN_PER_IP, REGISTER_PER_IP
from .repos import SessionRepo, UserRepo
from .security import validate_password_strength, verify_password

logger = logging.getLogger(__name__)

auth_bp = Blueprint("auth", __name__, url_prefix="/api/auth")

_EMAIL_RE = re.compile(r"^[^@\s]+@[^@\s]+\.[^@\s]+$")
_MAX_EMAIL_LEN = 254
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
    if not isinstance(raw, str):
        return None, "email must be a string"
    email = raw.strip().lower()
    if not email or len(email) > _MAX_EMAIL_LEN or not _EMAIL_RE.match(email):
        return None, "invalid email"
    return email, None


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
        return jsonify({"error": "email already registered"}), 409
    try:
        user = users.create(email=email, password=password, display_name=display_name)
    except IntegrityError:
        db.rollback()
        return jsonify({"error": "email already registered"}), 409

    sessions = SessionRepo(db)
    session_row, raw_id = sessions.create(
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
        return jsonify({"error": "invalid email or password"}), 401

    if not LOGIN_PER_EMAIL.hit(f"email:{email}"):
        return jsonify({"error": "too many attempts, try again later"}), 429

    db = get_session()
    users = UserRepo(db)
    user = users.get_by_email(email)
    if user is None or not user.is_active:
        return jsonify({"error": "invalid email or password"}), 401

    ok, rehash = verify_password(user.password_hash, password)
    if not ok:
        return jsonify({"error": "invalid email or password"}), 401
    if rehash is not None:
        users.update_password_hash(user, rehash)

    sessions = SessionRepo(db)
    session_row, raw_id = sessions.create(
        user_id=user.id,
        ip=_request_ip(),
        user_agent=request.headers.get("User-Agent"),
    )
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
    if session is not None:
        SessionRepo(db).revoke(session)
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
