"""SQLAlchemy engine + per-request session management.

Both Flask apps import ``init_app`` at startup and ``get_session`` inside
handlers. The engine is lazily created so Alembic (which uses its own engine)
doesn't fight with the Flask app's engine during migrations.
"""
from __future__ import annotations

from typing import Optional

from flask import Flask, g
from sqlalchemy import create_engine
from sqlalchemy.engine import Engine
from sqlalchemy.orm import Session, sessionmaker

from .config import get_config

_engine: Optional[Engine] = None
_SessionLocal: Optional[sessionmaker] = None


def get_engine() -> Engine:
    global _engine
    if _engine is None:
        cfg = get_config()
        _engine = create_engine(
            cfg.db_url,
            pool_pre_ping=True,
            pool_size=5,
            max_overflow=5,
            future=True,
        )
    return _engine


def _get_session_factory() -> sessionmaker:
    global _SessionLocal
    if _SessionLocal is None:
        _SessionLocal = sessionmaker(
            bind=get_engine(),
            autoflush=False,
            autocommit=False,
            expire_on_commit=False,
            future=True,
        )
    return _SessionLocal


def get_session() -> Session:
    """Return the request-scoped SQLAlchemy session, creating it on first use."""
    if "auth_db_session" not in g:
        g.auth_db_session = _get_session_factory()()
    return g.auth_db_session


def init_app(app: Flask) -> None:
    @app.teardown_appcontext
    def _close_session(exc):
        sess: Optional[Session] = g.pop("auth_db_session", None)
        if sess is None:
            return
        try:
            if exc is None:
                sess.commit()
            else:
                sess.rollback()
        finally:
            sess.close()
