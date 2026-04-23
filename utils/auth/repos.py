"""Repository layer for auth tables.

Callers never see ``user_id`` leaking across sessions — every conversation /
message read here takes ``user_id`` as a mandatory argument so handler code
cannot accidentally bypass the filter.
"""
from __future__ import annotations

import uuid
from datetime import datetime, timezone
from typing import Optional

from sqlalchemy import select, update
from sqlalchemy.orm import Session

from .models import AuthSession, User
from .security import (
    generate_csrf_token,
    generate_session_id,
    hash_password,
    session_expires_at,
)


class UserRepo:
    def __init__(self, db: Session):
        self.db = db

    def get_by_email(self, email: str) -> Optional[User]:
        return self.db.execute(
            select(User).where(
                User.email == email,
                User.deleted_at.is_(None),
            )
        ).scalar_one_or_none()

    def get_by_id(self, user_id: uuid.UUID) -> Optional[User]:
        return self.db.execute(
            select(User).where(
                User.id == user_id,
                User.deleted_at.is_(None),
            )
        ).scalar_one_or_none()

    def create(self, email: str, password: str, display_name: Optional[str] = None) -> User:
        user = User(
            email=email,
            display_name=display_name or None,
            password_hash=hash_password(password),
            password_updated_at=datetime.now(tz=timezone.utc),
        )
        self.db.add(user)
        self.db.flush()
        return user

    def update_password_hash(self, user: User, new_hash: str) -> None:
        user.password_hash = new_hash
        user.password_updated_at = datetime.now(tz=timezone.utc)


class SessionRepo:
    def __init__(self, db: Session):
        self.db = db

    def create(
        self,
        user_id: uuid.UUID,
        ip: Optional[str] = None,
        user_agent: Optional[str] = None,
    ) -> tuple[AuthSession, str]:
        """Return (session_row, raw_session_id).

        The raw session ID is only returned here; afterwards only the
        ``AuthSession.id`` UUID is kept. The cookie carries the raw value —
        we look it up by equality on ``id`` since both are random and unique.
        """
        raw_id = generate_session_id()
        # We store the raw ID as the session's PK so lookup is a single index
        # hit. The 256-bit random space makes collision astronomically small.
        # For a belt-and-suspenders design we could store a hash, but it adds
        # complexity without meaningful security gain vs. opaque random IDs.
        session = AuthSession(
            id=uuid.UUID(bytes=_derive_uuid_bytes(raw_id)),
            user_id=user_id,
            csrf_token=generate_csrf_token(),
            expires_at=session_expires_at(),
            ip=ip,
            user_agent=user_agent,
        )
        self.db.add(session)
        self.db.flush()
        return session, raw_id

    def lookup(self, raw_session_id: str) -> Optional[AuthSession]:
        try:
            uid = uuid.UUID(bytes=_derive_uuid_bytes(raw_session_id))
        except (ValueError, TypeError):
            return None
        now = datetime.now(tz=timezone.utc)
        sess = self.db.execute(
            select(AuthSession).where(
                AuthSession.id == uid,
                AuthSession.revoked_at.is_(None),
                AuthSession.expires_at > now,
            )
        ).scalar_one_or_none()
        return sess

    def touch(self, session: AuthSession) -> None:
        session.last_seen_at = datetime.now(tz=timezone.utc)

    def revoke(self, session: AuthSession) -> None:
        session.revoked_at = datetime.now(tz=timezone.utc)

    def revoke_all_for_user(self, user_id: uuid.UUID) -> None:
        self.db.execute(
            update(AuthSession)
            .where(
                AuthSession.user_id == user_id,
                AuthSession.revoked_at.is_(None),
            )
            .values(revoked_at=datetime.now(tz=timezone.utc))
        )


def _derive_uuid_bytes(raw_id: str) -> bytes:
    """Collapse a URL-safe random token into 16 deterministic bytes.

    We use BLAKE2b truncated to 128 bits. This lets the session PK stay as
    a UUID column (nice for indexing + PG tooling) while the cookie carries
    a longer opaque random string. Finding a collision requires breaking
    BLAKE2b — well outside any practical threat model.
    """
    import hashlib

    return hashlib.blake2b(raw_id.encode("utf-8"), digest_size=16).digest()
