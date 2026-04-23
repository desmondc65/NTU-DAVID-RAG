"""``/api/conversations/*`` routes — scoped per-user, per-app.

Both Flask apps register this blueprint; the ``app`` scope comes from
``APP_SCOPE`` via the shared config so rag-web serves conversations with
``app='rag'`` and graphrag-web serves ``app='graphrag'``.
"""
from __future__ import annotations

import uuid
from typing import Any

from flask import Blueprint, jsonify, request

from .chat_repos import (
    ConversationRepo,
    MessageRepo,
    conversation_to_payload,
    message_to_payload,
    parse_uuid,
)
from .config import get_config
from .db import get_session
from .decorators import csrf_protect, current_user, login_required

chat_bp = Blueprint("chat", __name__, url_prefix="/api/conversations")


def _current_scope() -> str:
    return get_config().app_scope


def _json_body() -> dict[str, Any]:
    body = request.get_json(silent=True)
    return body if isinstance(body, dict) else {}


@chat_bp.get("")
@login_required
def list_conversations():
    user = current_user()
    assert user is not None  # @login_required guarantees
    db = get_session()
    rows = ConversationRepo(db).list_for_user(user.id, _current_scope())
    return jsonify(rows)


@chat_bp.post("")
@login_required
@csrf_protect
def create_conversation():
    user = current_user()
    assert user is not None
    body = _json_body()
    title = body.get("title") if isinstance(body.get("title"), str) else None

    db = get_session()
    conv = ConversationRepo(db).create(
        user_id=user.id,
        app=_current_scope(),
        title=title,
    )
    db.commit()
    return jsonify(conversation_to_payload(conv, message_count=0)), 201


@chat_bp.patch("/<conv_id>")
@login_required
@csrf_protect
def rename_conversation(conv_id: str):
    user = current_user()
    assert user is not None
    cid = parse_uuid(conv_id)
    if cid is None:
        return jsonify({"error": "not found"}), 404

    body = _json_body()
    new_title = body.get("title")
    if not isinstance(new_title, str) or not new_title.strip():
        return jsonify({"error": "title must be a non-empty string"}), 400

    db = get_session()
    repo = ConversationRepo(db)
    conv = repo.get(cid, user.id, _current_scope())
    if conv is None:
        return jsonify({"error": "not found"}), 404
    repo.rename(conv, new_title.strip())
    db.commit()
    return jsonify(conversation_to_payload(conv))


@chat_bp.delete("/<conv_id>")
@login_required
@csrf_protect
def delete_conversation(conv_id: str):
    user = current_user()
    assert user is not None
    cid = parse_uuid(conv_id)
    if cid is None:
        return jsonify({"error": "not found"}), 404

    db = get_session()
    repo = ConversationRepo(db)
    conv = repo.get(cid, user.id, _current_scope())
    if conv is None:
        return jsonify({"error": "not found"}), 404
    repo.soft_delete(conv)
    db.commit()
    return "", 204


@chat_bp.get("/<conv_id>/messages")
@login_required
def list_messages(conv_id: str):
    user = current_user()
    assert user is not None
    cid = parse_uuid(conv_id)
    if cid is None:
        return jsonify({"error": "not found"}), 404

    db = get_session()
    # Ownership check first — gives 404 if cross-user access attempted.
    if ConversationRepo(db).get(cid, user.id, _current_scope()) is None:
        return jsonify({"error": "not found"}), 404

    limit_raw = request.args.get("limit", "200")
    try:
        limit = int(limit_raw)
    except ValueError:
        return jsonify({"error": "limit must be int"}), 400

    before_raw = request.args.get("before")
    before_dt = None
    if before_raw:
        from datetime import datetime
        try:
            before_dt = datetime.fromisoformat(before_raw.replace("Z", "+00:00"))
        except ValueError:
            return jsonify({"error": "invalid 'before' timestamp"}), 400

    rows = MessageRepo(db).list_for_conversation(
        conversation_id=cid,
        user_id=user.id,
        limit=limit,
        before=before_dt,
    )
    return jsonify([message_to_payload(m) for m in rows])


@chat_bp.delete("/<conv_id>/messages/<msg_id>")
@login_required
@csrf_protect
def delete_message(conv_id: str, msg_id: str):
    user = current_user()
    assert user is not None
    cid = parse_uuid(conv_id)
    mid = parse_uuid(msg_id)
    if cid is None or mid is None:
        return jsonify({"error": "not found"}), 404

    db = get_session()
    if ConversationRepo(db).get(cid, user.id, _current_scope()) is None:
        return jsonify({"error": "not found"}), 404

    ok = MessageRepo(db).soft_delete_by_id(mid, user.id)
    if not ok:
        return jsonify({"error": "not found"}), 404
    db.commit()
    return "", 204
