"""Shared auth module for the unified RAG + GraphRAG stack.

Typical wiring inside a Flask app:

    from utils.auth import init_auth, auth_bp

    init_auth(app)
    app.register_blueprint(auth_bp)

Handlers gate themselves with ``@login_required`` and read the caller via
``current_user()`` / ``current_session()``.
"""
from __future__ import annotations

from flask import Flask

from .blueprint import auth_bp
from .chat_blueprint import chat_bp
from .config import get_config
from .db import init_app as _init_db
from .decorators import (
    csrf_protect,
    current_session,
    current_user,
    login_required,
)

__all__ = [
    "auth_bp",
    "chat_bp",
    "current_session",
    "current_user",
    "csrf_protect",
    "init_auth",
    "login_required",
]


def init_auth(app: Flask) -> None:
    """Attach DB session lifecycle + config sanity check to ``app``."""
    # Trigger config validation at startup rather than on the first request.
    get_config()
    _init_db(app)
