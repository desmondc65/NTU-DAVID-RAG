"""auth_events audit log.

Revision ID: 0002_auth_events
Revises: 0001_initial
Create Date: 2026-04-24
"""
from __future__ import annotations

from alembic import op
import sqlalchemy as sa
from sqlalchemy.dialects import postgresql

revision = "0002_auth_events"
down_revision = "0001_initial"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.create_table(
        "auth_events",
        sa.Column("id", postgresql.UUID(as_uuid=True), primary_key=True),
        sa.Column(
            "user_id",
            postgresql.UUID(as_uuid=True),
            sa.ForeignKey("users.id", ondelete="SET NULL"),
            nullable=True,
        ),
        sa.Column("event_type", sa.String(40), nullable=False),
        sa.Column("ip", postgresql.INET(), nullable=True),
        sa.Column("user_agent", sa.Text(), nullable=True),
        sa.Column("metadata", postgresql.JSONB(), nullable=True),
        sa.Column(
            "created_at",
            sa.DateTime(timezone=True),
            nullable=False,
            server_default=sa.text("now()"),
        ),
    )
    op.create_index(
        "ix_auth_events_user_created",
        "auth_events",
        ["user_id", "created_at"],
    )
    op.create_index(
        "ix_auth_events_type_created",
        "auth_events",
        ["event_type", "created_at"],
    )


def downgrade() -> None:
    op.drop_index("ix_auth_events_type_created", table_name="auth_events")
    op.drop_index("ix_auth_events_user_created", table_name="auth_events")
    op.drop_table("auth_events")
