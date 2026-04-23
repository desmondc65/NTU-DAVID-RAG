"""Conversation + Message repositories.

Every method takes ``user_id`` as a mandatory argument. The repo layer is
where cross-user isolation is enforced — handlers cannot accidentally bypass
the filter because ``user_id`` is never optional.

Returning ``None`` for a "not found" looks indistinguishable to callers
whether the row doesn't exist or belongs to a different user — this is
intentional so we don't leak existence across users.
"""
from __future__ import annotations

import uuid
from datetime import datetime, timezone
from typing import Any, Iterable, Optional

from sqlalchemy import and_, func, select, update
from sqlalchemy.orm import Session

from .models import Conversation, Message

_VALID_ROLES = {"user", "assistant", "system"}


class ConversationRepo:
    def __init__(self, db: Session):
        self.db = db

    def list_for_user(self, user_id: uuid.UUID, app: str) -> list[dict[str, Any]]:
        """Sidebar payload: newest first, soft-deleted excluded."""
        msg_count = func.count(Message.id).label("message_count")
        stmt = (
            select(
                Conversation.id,
                Conversation.title,
                Conversation.created_at,
                Conversation.updated_at,
                Conversation.last_message_at,
                msg_count,
            )
            .outerjoin(
                Message,
                and_(
                    Message.conversation_id == Conversation.id,
                    Message.deleted_at.is_(None),
                ),
            )
            .where(
                Conversation.user_id == user_id,
                Conversation.app == app,
                Conversation.deleted_at.is_(None),
            )
            .group_by(Conversation.id)
            .order_by(
                func.coalesce(Conversation.last_message_at, Conversation.created_at).desc()
            )
        )
        rows = self.db.execute(stmt).all()
        return [
            {
                "id": str(r.id),
                "title": r.title,
                "created_at": r.created_at.isoformat(),
                "updated_at": r.updated_at.isoformat(),
                "last_message_at": r.last_message_at.isoformat() if r.last_message_at else None,
                "message_count": int(r.message_count or 0),
            }
            for r in rows
        ]

    def get(self, conversation_id: uuid.UUID, user_id: uuid.UUID, app: str) -> Optional[Conversation]:
        return self.db.execute(
            select(Conversation).where(
                Conversation.id == conversation_id,
                Conversation.user_id == user_id,
                Conversation.app == app,
                Conversation.deleted_at.is_(None),
            )
        ).scalar_one_or_none()

    def create(
        self,
        user_id: uuid.UUID,
        app: str,
        title: Optional[str] = None,
    ) -> Conversation:
        conv = Conversation(
            user_id=user_id,
            app=app,
            title=(title or "New chat")[:200],
        )
        self.db.add(conv)
        self.db.flush()
        return conv

    def rename(self, conversation: Conversation, title: str) -> None:
        conversation.title = title[:200] or "New chat"

    def soft_delete(self, conversation: Conversation) -> None:
        conversation.deleted_at = datetime.now(tz=timezone.utc)

    def touch_last_message_at(self, conversation: Conversation, at: Optional[datetime] = None) -> None:
        conversation.last_message_at = at or datetime.now(tz=timezone.utc)


class MessageRepo:
    def __init__(self, db: Session):
        self.db = db

    def list_for_conversation(
        self,
        conversation_id: uuid.UUID,
        user_id: uuid.UUID,
        limit: int = 200,
        before: Optional[datetime] = None,
    ) -> list[Message]:
        """Oldest → newest within the returned slice."""
        conditions = [
            Message.conversation_id == conversation_id,
            Message.user_id == user_id,
            Message.deleted_at.is_(None),
        ]
        if before is not None:
            conditions.append(Message.created_at < before)
        stmt = (
            select(Message)
            .where(*conditions)
            .order_by(Message.created_at.asc())
            .limit(max(1, min(limit, 500)))
        )
        return list(self.db.execute(stmt).scalars())

    def recent_turns(
        self,
        conversation_id: uuid.UUID,
        user_id: uuid.UUID,
        limit_turns: int = 30,
        per_turn_char_cap: int = 6000,
    ) -> list[dict[str, str]]:
        """History suitable for replay into the LLM — built server-side.

        Returns the last ``limit_turns`` user/assistant turns in chronological
        order, truncated to ``per_turn_char_cap`` characters each.
        """
        stmt = (
            select(Message)
            .where(
                Message.conversation_id == conversation_id,
                Message.user_id == user_id,
                Message.deleted_at.is_(None),
                Message.role.in_(("user", "assistant")),
            )
            .order_by(Message.created_at.desc())
            .limit(max(1, min(limit_turns, 100)))
        )
        rows = list(self.db.execute(stmt).scalars())
        rows.reverse()
        return [
            {"role": m.role, "content": (m.content or "")[:per_turn_char_cap]}
            for m in rows
        ]

    def append(
        self,
        conversation_id: uuid.UUID,
        user_id: uuid.UUID,
        role: str,
        content: str,
        sources: Optional[Any] = None,
        metadata: Optional[dict] = None,
        parent_message_id: Optional[uuid.UUID] = None,
    ) -> Message:
        if role not in _VALID_ROLES:
            raise ValueError(f"invalid role {role!r}")
        msg = Message(
            conversation_id=conversation_id,
            user_id=user_id,
            role=role,
            content=content,
            sources=sources,
            metadata_=metadata,
            parent_message_id=parent_message_id,
        )
        self.db.add(msg)
        self.db.flush()
        return msg

    def soft_delete_by_id(
        self,
        message_id: uuid.UUID,
        user_id: uuid.UUID,
    ) -> bool:
        result = self.db.execute(
            update(Message)
            .where(
                Message.id == message_id,
                Message.user_id == user_id,
                Message.deleted_at.is_(None),
            )
            .values(deleted_at=datetime.now(tz=timezone.utc))
        )
        return result.rowcount > 0


def message_to_payload(m: Message) -> dict[str, Any]:
    return {
        "id": str(m.id),
        "role": m.role,
        "content": m.content,
        "sources": m.sources,
        "metadata": m.metadata_,
        "parent_message_id": str(m.parent_message_id) if m.parent_message_id else None,
        "created_at": m.created_at.isoformat() if m.created_at else None,
    }


def conversation_to_payload(c: Conversation, message_count: Optional[int] = None) -> dict[str, Any]:
    data = {
        "id": str(c.id),
        "app": c.app,
        "title": c.title,
        "created_at": c.created_at.isoformat() if c.created_at else None,
        "updated_at": c.updated_at.isoformat() if c.updated_at else None,
        "last_message_at": c.last_message_at.isoformat() if c.last_message_at else None,
    }
    if message_count is not None:
        data["message_count"] = message_count
    return data


def parse_uuid(raw: Any) -> Optional[uuid.UUID]:
    if raw is None:
        return None
    try:
        return uuid.UUID(str(raw))
    except (ValueError, TypeError):
        return None
