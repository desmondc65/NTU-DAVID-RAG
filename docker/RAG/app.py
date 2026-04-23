"""
RAG Web Application – Flask backend.

Provides API endpoints for:
  - Listing / uploading / deleting papers (PDF + Fortran)
  - Running RAG queries against the vector store
"""
from __future__ import annotations

import json
import logging
import os
import shutil
import sys
import traceback
import uuid
import mimetypes
import base64
from threading import Lock
from pathlib import Path
from typing import Dict, List

from flask import Flask, jsonify, request, send_from_directory
from flask_cors import CORS
from dotenv import load_dotenv
from werkzeug.utils import secure_filename

load_dotenv()

# ── path setup ────────────────────────────────────────────────────────────
# When running inside Docker, PROJECT_ROOT is /app (mounted)
PROJECT_ROOT = Path(os.getenv("PROJECT_ROOT", "/app"))
sys.path.insert(0, str(PROJECT_ROOT))

DB_PATH = Path(os.getenv("DB_PATH", str(PROJECT_ROOT / "db")))
DATA_PATH = Path(os.getenv("DATA_PATH", str(PROJECT_ROOT / "data")))
UPLOAD_DIR = DATA_PATH / "uploads"
OUTPUT_DIR = DATA_PATH / "ingest_output"
TMP_UPLOAD_DIR = DATA_PATH / "tmp_uploads"

UPLOAD_DIR.mkdir(parents=True, exist_ok=True)
OUTPUT_DIR.mkdir(parents=True, exist_ok=True)
TMP_UPLOAD_DIR.mkdir(parents=True, exist_ok=True)

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

app = Flask(__name__, static_folder="frontend/dist", static_url_path="")
CORS(app)

# Auth — shared module provides /api/auth/* + login_required + csrf_protect.
from utils.auth import auth_bp, chat_bp, csrf_protect, init_auth, login_required
from utils.auth.chat_repos import ConversationRepo, MessageRepo
from utils.auth.db import get_session as get_auth_session
from utils.auth.decorators import current_user
init_auth(app)
app.register_blueprint(auth_bp)
app.register_blueprint(chat_bp)

# ── lazy-loaded heavy modules ─────────────────────────────────────────────
_rag_engine = None
_qdrant_access_lock = Lock()


def _get_rag_engine():
    """Lazily initialise the RAG query engine (loads models on first call)."""
    global _rag_engine
    if _rag_engine is None:
        from utils.orchestrator.rag_query import RAGQueryEngine
        _rag_engine = RAGQueryEngine(db_path=DB_PATH)
    return _rag_engine


def _reload_rag_engine():
    """Force reload of the RAG engine (after paper add/remove)."""
    global _rag_engine
    if _rag_engine is not None:
        try:
            _rag_engine.close()
        except Exception:
            logger.warning("Failed to close existing RAG engine cleanly.", exc_info=True)
    _rag_engine = None


def _get_registry() -> List[Dict]:
    registry_path = DB_PATH / "paper_registry.json"
    if registry_path.exists():
        with open(registry_path, "r", encoding="utf-8") as f:
            return json.load(f)
    return []


def _save_registry(registry: List[Dict]) -> None:
    registry_path = DB_PATH / "paper_registry.json"
    DB_PATH.mkdir(parents=True, exist_ok=True)
    with open(registry_path, "w", encoding="utf-8") as f:
        json.dump(registry, f, indent=4, ensure_ascii=False)


# ── Frontend routes ───────────────────────────────────────────────────────

@app.route("/")
def serve_frontend():
    return send_from_directory(app.static_folder, "index.html")


@app.route("/<path:path>")
def serve_static(path):
    file_path = Path(app.static_folder) / path
    if file_path.exists():
        return send_from_directory(app.static_folder, path)
    return send_from_directory(app.static_folder, "index.html")


# ── API: Papers ───────────────────────────────────────────────────────────

@app.route("/api/papers", methods=["GET"])
@login_required
def list_papers():
    """Return the paper registry."""
    return jsonify(_get_registry())


@app.route("/api/papers", methods=["POST"])
@login_required
@csrf_protect
def upload_paper():
    """
    Upload a PDF + Fortran file pair.
    Expects multipart form with 'pdf' and 'fortran' file fields.
    """
    if "pdf" not in request.files:
        return jsonify({"error": "Missing PDF file"}), 400
    if "fortran" not in request.files:
        return jsonify({"error": "Missing Fortran file"}), 400

    pdf_file = request.files["pdf"]
    fortran_file = request.files["fortran"]

    if not pdf_file.filename or not fortran_file.filename:
        return jsonify({"error": "Empty filename(s)"}), 400

    pdf_name = secure_filename(pdf_file.filename)
    fortran_name = secure_filename(fortran_file.filename)

    # Stage incoming uploads in a temporary directory first.
    request_tmp_dir = TMP_UPLOAD_DIR / uuid.uuid4().hex
    request_tmp_dir.mkdir(parents=True, exist_ok=True)

    pdf_path = request_tmp_dir / pdf_name
    fortran_path = request_tmp_dir / fortran_name
    pdf_file.save(str(pdf_path))
    fortran_file.save(str(fortran_path))

    try:
        from utils.orchestrator.ingest_paper import ingest_paper_and_code
        from utils.orchestrator.store_to_db import store_ingested_data

        logger.info("Starting ingestion for %s + %s", pdf_name, fortran_name)

        # Step 1: Ingest (PDF extraction + Fortran digest)
        ingest_result = ingest_paper_and_code(
            pdf_path=pdf_path,
            fortran_path=fortran_path,
            output_dir=DATA_PATH,
            db_path=str(DB_PATH),
        )

        with _qdrant_access_lock:
            # Close any active reader engine before opening a writer client.
            _reload_rag_engine()

            # Step 2: Chunk, embed, store
            store_result = store_ingested_data(
                ingest_result=ingest_result,
                db_path=DB_PATH,
            )

        return jsonify({
            "status": "ok",
            "message": f"Ingested {ingest_result.get('paper_dir', pdf_name)}",
            "store_result": store_result,
            "paper_dir": ingest_result.get("paper_dir", ""),
        })

    except Exception as e:
        logger.error("Ingestion failed: %s", traceback.format_exc())
        return jsonify({"error": str(e)}), 500
    finally:
        shutil.rmtree(request_tmp_dir, ignore_errors=True)


@app.route("/api/papers/<path:paper_title>", methods=["DELETE"])
@login_required
@csrf_protect
def delete_paper(paper_title: str):
    """
    Remove a paper from the registry and delete its vectors from Qdrant.
    """
    try:
        from utils.s2_embedding.qdrant_store import QdrantVectorStore
        from qdrant_client import models

        with _qdrant_access_lock:
            # Close any active reader engine before opening a writer client.
            _reload_rag_engine()

            # 1. Remove from Qdrant
            qdrant_dir = str(DB_PATH / "qdrant_data")
            if Path(qdrant_dir).exists():
                store = QdrantVectorStore(persist_dir=qdrant_dir)
                try:
                    # Delete all points matching the paper title
                    store.client.delete(
                        collection_name=store.collection_name,
                        points_selector=models.FilterSelector(
                            filter=models.Filter(
                                must=[
                                    models.FieldCondition(
                                        key="paper_title",
                                        match=models.MatchValue(value=paper_title),
                                    )
                                ]
                            )
                        ),
                    )
                    logger.info("Deleted Qdrant points for '%s'", paper_title)
                finally:
                    store.close()

            # 2. Remove from registry
            registry = _get_registry()
            registry = [p for p in registry if p.get("paper_title") != paper_title]
            _save_registry(registry)

        return jsonify({"status": "ok", "message": f"Deleted '{paper_title}'"})

    except Exception as e:
        logger.error("Delete failed: %s", traceback.format_exc())
        return jsonify({"error": str(e)}), 500


# ── API: Retry metadata extraction ────────────────────────────────────────

@app.route("/api/papers/retry_metadata", methods=["POST"])
@login_required
@csrf_protect
def retry_metadata():
    """
    Re-run LLM title/author extraction for a paper already in the database.

    Body (JSON), provide ONE of:
        {"paper_title": "..."}          # current (possibly empty) title
        {"paper_dir":   "..."}          # filesystem path to the paper directory

    ``paper_dir`` may be absolute (``/app/data/...``) or relative to the
    server's ``DATA_PATH``. When only ``paper_title`` is given, it must
    uniquely identify a registry entry.

    Propagates the new title + authors through ``metadata.json``, the
    content-list JSON, the Fortran digest JSON, ``paper_registry.json``,
    and the Qdrant payloads of both ``rag_embeddings`` and
    ``paper_profiles`` collections.
    """
    body = request.get_json(silent=True) or {}
    paper_title = body.get("paper_title")
    paper_dir = body.get("paper_dir")

    if paper_title is None and not paper_dir:
        return jsonify({
            "error": "Provide paper_title (string, may be \"\") or paper_dir."
        }), 400

    try:
        from utils.orchestrator.retry_metadata import (
            resolve_paper_dir,
            retry_paper_metadata,
        )
    except Exception as e:
        logger.error("retry_metadata import failed: %s", traceback.format_exc())
        return jsonify({"error": f"Module import failed: {e}"}), 500

    try:
        resolved = resolve_paper_dir(
            db_path=DB_PATH,
            paper_title=paper_title,
            paper_dir=paper_dir,
            data_root=DATA_PATH,
        )
    except FileNotFoundError as e:
        return jsonify({"error": str(e)}), 404
    except ValueError as e:
        return jsonify({"error": str(e)}), 409

    try:
        with _qdrant_access_lock:
            # Release the active reader engine so retry_paper_metadata can
            # open its own writer client against the Qdrant on-disk store.
            _reload_rag_engine()
            summary = retry_paper_metadata(
                db_path=DB_PATH,
                paper_dir=resolved,
            )
        return jsonify({"status": "ok", **summary})
    except FileNotFoundError as e:
        return jsonify({"error": str(e)}), 404
    except RuntimeError as e:
        # LLM still returned empty — no state mutated.
        return jsonify({"error": str(e)}), 422
    except Exception as e:
        logger.error("Retry metadata failed: %s", traceback.format_exc())
        return jsonify({"error": str(e)}), 500


# ── API: Query ────────────────────────────────────────────────────────────

@app.route("/api/query", methods=["POST"])
@login_required
@csrf_protect
def rag_query():
    """Run a RAG query within a server-side conversation.

    Request JSON:
        {"query": "...", "top_k": 5, "conversation_id": "<uuid-or-null>"}

    - ``history`` is no longer read from the request; it is loaded from the
      DB for ``(user_id, conversation_id)``. This closes a forgery hole.
    - If ``conversation_id`` is omitted, a new conversation is created and
      its id is returned in the response.
    """
    data = request.get_json(silent=True) or {}
    query = str(data.get("query") or "").strip()
    if not query:
        return jsonify({"error": "Empty query"}), 400

    top_k = data.get("top_k", 10)

    user = current_user()
    assert user is not None  # @login_required guarantees

    from utils.auth.chat_repos import parse_uuid
    db = get_auth_session()
    conv_repo = ConversationRepo(db)
    msg_repo = MessageRepo(db)

    # Resolve / create the conversation under the current user + app scope.
    raw_conv_id = data.get("conversation_id")
    conv = None
    if raw_conv_id:
        cid = parse_uuid(raw_conv_id)
        if cid is None:
            return jsonify({"error": "invalid conversation_id"}), 400
        conv = conv_repo.get(cid, user.id, "rag")
        if conv is None:
            return jsonify({"error": "conversation not found"}), 404
    if conv is None:
        # Seed the title with a short snippet of the first user query.
        conv = conv_repo.create(user_id=user.id, app="rag", title=query[:80])
        db.flush()

    # History comes from the DB — never from the client.
    history = msg_repo.recent_turns(
        conversation_id=conv.id,
        user_id=user.id,
        limit_turns=30,
        per_turn_char_cap=6000,
    )

    try:
        with _qdrant_access_lock:
            engine = _get_rag_engine()
            result = engine.query(user_query=query, top_k=top_k, conversation_history=history)

        # Serialise sources (strip non-JSON-safe fields)
        sources = []
        for s in result.get("sources", []):
            raw_meta = s.get("metadata", {})
            normalized_meta = {k: str(v) for k, v in raw_meta.items()}
            if raw_meta.get("content_type") == "image":
                img_path = raw_meta.get("img_path")
                if img_path:
                    img_file = Path(str(img_path))
                    if img_file.exists() and img_file.is_file():
                        try:
                            mime = mimetypes.guess_type(str(img_file))[0] or "image/jpeg"
                            encoded = base64.b64encode(img_file.read_bytes()).decode("ascii")
                            normalized_meta["image_data_url"] = f"data:{mime};base64,{encoded}"
                        except Exception as img_err:
                            logger.warning("Failed to encode image for source payload: %s", img_err)
            sources.append({
                "text": s.get("text", "")[:500],
                "metadata": normalized_meta,
                "score": s.get("rerank_score", s.get("score", 0)),
            })

        answer_text = result.get("answer", "")

        # Persist both turns atomically with the request's DB session.
        user_msg = msg_repo.append(
            conversation_id=conv.id,
            user_id=user.id,
            role="user",
            content=query,
            metadata={"top_k": int(top_k) if isinstance(top_k, int) else None},
        )
        assistant_msg = msg_repo.append(
            conversation_id=conv.id,
            user_id=user.id,
            role="assistant",
            content=answer_text,
            sources=sources or None,
            metadata={"top_k": int(top_k) if isinstance(top_k, int) else None},
            parent_message_id=user_msg.id,
        )
        conv_repo.touch_last_message_at(conv)
        # SQLAlchemy session is flushed+committed by the teardown hook on
        # normal returns; explicit commit here makes failure modes simpler
        # and lets us return IDs that are guaranteed persisted.
        db.commit()

        return jsonify({
            "answer": answer_text,
            "sources": sources,
            "conversation_id": str(conv.id),
            "message_ids": {
                "user": str(user_msg.id),
                "assistant": str(assistant_msg.id),
            },
        })

    except Exception as e:
        db.rollback()
        logger.error("Query failed: %s", traceback.format_exc())
        return jsonify({"error": str(e)}), 500


# ── API: Status ───────────────────────────────────────────────────────────

@app.route("/api/status", methods=["GET"])
@login_required
def status():
    """Health check with basic stats."""
    papers = _get_registry()
    return jsonify({
        "status": "ok",
        "papers_count": len(papers),
        "db_path": str(DB_PATH),
    })


# ── Main ──────────────────────────────────────────────────────────────────

if __name__ == "__main__":
    port = int(os.getenv("PORT", "5000"))
    app.run(host="0.0.0.0", port=port, debug=True)
