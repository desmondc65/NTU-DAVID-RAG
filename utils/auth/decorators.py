"""Auth / CSRF decorators.

``@login_required`` attaches the resolved ``User`` and ``AuthSession`` onto
``flask.g`` so handlers can call ``current_user()`` and ``current_session()``
without re-running the DB lookup.
"""
from __future__ import annotations

from functools import wraps
from typing import Callable, Optional

from flask import Response, g, jsonify, request

from .config import get_config
from .db import get_session
from .models import AuthSession, User
from .repos import SessionRepo, UserRepo
from .security import constant_time_equals


def _load_session_and_user() -> tuple[Optional[AuthSession], Optional[User]]:
    if "auth_session" in g and "auth_user" in g:
        return g.auth_session, g.auth_user

    cfg = get_config()
    cookie = request.cookies.get(cfg.session_cookie_name)
    if not cookie:
        g.auth_session = None
        g.auth_user = None
        return None, None

    db = get_session()
    session = SessionRepo(db).lookup(cookie)
    if session is None:
        g.auth_session = None
        g.auth_user = None
        return None, None

    user = UserRepo(db).get_by_id(session.user_id)
    if user is None or not user.is_active:
        g.auth_session = None
        g.auth_user = None
        return None, None

    # Sliding expiration: touch each request. Cheap single-column update.
    SessionRepo(db).touch(session)

    g.auth_session = session
    g.auth_user = user
    return session, user


def current_user() -> Optional[User]:
    _, user = _load_session_and_user()
    return user


def current_session() -> Optional[AuthSession]:
    session, _ = _load_session_and_user()
    return session


def login_required(fn: Callable) -> Callable:
    @wraps(fn)
    def wrapper(*args, **kwargs):
        _, user = _load_session_and_user()
        if user is None:
            return jsonify({"error": "authentication required"}), 401
        return fn(*args, **kwargs)

    return wrapper


SAFE_METHODS = {"GET", "HEAD", "OPTIONS"}


def csrf_protect(fn: Callable) -> Callable:
    """Require a matching CSRF header on state-changing requests.

    Double-submit cookie pattern: the client sends the value of the
    ``csrf_token`` cookie in an ``X-CSRF-Token`` header. We compare it to
    the token stored on the active session row (not just the cookie), so
    an attacker cannot set-and-submit their own cookie value.
    """
    @wraps(fn)
    def wrapper(*args, **kwargs):
        if request.method in SAFE_METHODS:
            return fn(*args, **kwargs)

        session, _ = _load_session_and_user()
        if session is None:
            return jsonify({"error": "authentication required"}), 401

        header_token = request.headers.get("X-CSRF-Token", "")
        if not header_token or not constant_time_equals(header_token, session.csrf_token):
            return jsonify({"error": "csrf check failed"}), 403

        return fn(*args, **kwargs)

    return wrapper


def apply_session_cookies(response: Response, raw_session_id: str, csrf_token: str) -> Response:
    cfg = get_config()
    max_age_s = cfg.session_ttl_days * 24 * 3600

    response.set_cookie(
        cfg.session_cookie_name,
        raw_session_id,
        max_age=max_age_s,
        httponly=True,
        secure=cfg.session_cookie_secure,
        samesite="Lax",
        path="/",
    )
    response.set_cookie(
        cfg.csrf_cookie_name,
        csrf_token,
        max_age=max_age_s,
        httponly=False,  # JS must read this to echo in X-CSRF-Token
        secure=cfg.session_cookie_secure,
        samesite="Lax",
        path="/",
    )
    return response


def clear_session_cookies(response: Response) -> Response:
    cfg = get_config()
    for name in (cfg.session_cookie_name, cfg.csrf_cookie_name):
        response.delete_cookie(name, path="/")
    return response
