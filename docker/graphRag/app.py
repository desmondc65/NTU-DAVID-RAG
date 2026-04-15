"""
GraphRAG Web Application — Flask backend.

Endpoints
---------
- ``GET  /api/status``  — whether the graph is built, with build stats.
- ``POST /api/build``   — (re)build the graph from the chunk store.
- ``POST /api/query``   — answer a question via local or global search.
- ``GET  /api/papers``  — paper registry (same source as the vector RAG).
- ``GET  /api/graph``   — node/edge dump (for visualisation).
- ``GET  /api/communities`` — list of community summaries.

The engine is lazy-loaded on first use so the container starts quickly.
All long-running calls (build, query) are serialised behind a single
lock because both open the Qdrant on-disk collection.
"""
from __future__ import annotations

import json
import logging
import os
import shutil
import sys
import traceback
import uuid
from pathlib import Path
from threading import Lock
from typing import Any, Dict, List

from dotenv import load_dotenv
from flask import Flask, jsonify, request, send_from_directory
from flask_cors import CORS
from werkzeug.utils import secure_filename

load_dotenv()

PROJECT_ROOT = Path(os.getenv("PROJECT_ROOT", "/app"))
sys.path.insert(0, str(PROJECT_ROOT))

# GraphRAG has its OWN database — mounted by docker-compose from
# ../../graph_db and ../../graph_data (not the vector RAG's db/).
DB_PATH = Path(os.getenv("DB_PATH", str(PROJECT_ROOT / "db")))
DATA_PATH = Path(os.getenv("DATA_PATH", str(PROJECT_ROOT / "data")))

UPLOAD_DIR = DATA_PATH / "uploads"
OUTPUT_DIR = DATA_PATH / "ingest_output"
TMP_UPLOAD_DIR = DATA_PATH / "tmp_uploads"

for d in (DB_PATH, DATA_PATH, UPLOAD_DIR, OUTPUT_DIR, TMP_UPLOAD_DIR):
    d.mkdir(parents=True, exist_ok=True)

logging.basicConfig(level=logging.INFO, format="%(levelname)s %(name)s | %(message)s")
logger = logging.getLogger(__name__)

app = Flask(__name__, static_folder="frontend/dist", static_url_path="")
CORS(app)


# ── Frontend routes ───────────────────────────────────────────────────────

@app.route("/")
def serve_frontend():
    return send_from_directory(app.static_folder, "index.html")


@app.route("/<path:path>")
def serve_static(path: str):
    if path.startswith("api/"):
        # Let the API routes handle these — shouldn't normally match here.
        return jsonify({"error": "not found"}), 404
    file_path = Path(app.static_folder) / path
    if file_path.exists() and file_path.is_file():
        return send_from_directory(app.static_folder, path)
    return send_from_directory(app.static_folder, "index.html")

_engine = None
_engine_lock = Lock()


def _save_registry(registry: List[Dict]) -> None:
    registry_path = DB_PATH / "paper_registry.json"
    with open(registry_path, "w", encoding="utf-8") as f:
        json.dump(registry, f, indent=4, ensure_ascii=False)


def _load_registry() -> List[Dict]:
    registry_path = DB_PATH / "paper_registry.json"
    if registry_path.exists():
        with open(registry_path, "r", encoding="utf-8") as f:
            return json.load(f)
    return []


def _get_engine():
    """Lazily instantiate GraphRAGEngine (loads embedder & LLM client)."""
    global _engine
    if _engine is None:
        from graphRag.graph_rag import GraphRAGEngine
        _engine = GraphRAGEngine(db_path=DB_PATH)
    return _engine


def _reload_engine() -> None:
    global _engine
    if _engine is not None:
        try:
            _engine.close()
        except Exception:
            logger.warning("Failed to close GraphRAGEngine cleanly.", exc_info=True)
    _engine = None


# ── API: Status ───────────────────────────────────────────────────────────

@app.route("/api/status", methods=["GET"])
def status():
    try:
        with _engine_lock:
            engine = _get_engine()
            info = engine.status()
        return jsonify({
            "service": "graphRag",
            "db_path": str(DB_PATH),
            **info,
        })
    except Exception as e:
        logger.error("Status failed: %s", traceback.format_exc())
        return jsonify({"error": str(e)}), 500


# ── API: Build ────────────────────────────────────────────────────────────

@app.route("/api/build", methods=["POST"])
def build_graph():
    """
    (Re)build the knowledge graph.

    Body (optional JSON):
        {
            "paper_filter": ["Title A", "Title B"],
            "skip_fortran": true,
            "max_chunks": 500
        }
    """
    body = request.get_json(silent=True) or {}
    paper_filter = body.get("paper_filter") or None
    if paper_filter is not None and not isinstance(paper_filter, list):
        return jsonify({"error": "paper_filter must be a list"}), 400
    skip_fortran = bool(body.get("skip_fortran", False))
    max_chunks = body.get("max_chunks")
    if max_chunks is not None:
        try:
            max_chunks = int(max_chunks)
        except (TypeError, ValueError):
            return jsonify({"error": "max_chunks must be int"}), 400

    try:
        with _engine_lock:
            # Close any cached engine so we can reopen Qdrant cleanly.
            _reload_engine()
            engine = _get_engine()
            stats = engine.build(
                paper_filter=paper_filter,
                skip_fortran=skip_fortran,
                max_chunks=max_chunks,
            )
        return jsonify({"status": "ok", "stats": stats})
    except Exception as e:
        logger.error("Build failed: %s", traceback.format_exc())
        return jsonify({"error": str(e)}), 500


# ── API: Query ────────────────────────────────────────────────────────────

@app.route("/api/query", methods=["POST"])
def query():
    """
    Run a GraphRAG query.

    Body (JSON):
        {
            "query": "...",
            "mode": "auto" | "local" | "global",
            "n_hop": 1,
            "max_chunks": 20,
            "candidate_top_k": 12,
            "keep_top_k": 8
        }
    """
    data = request.get_json(silent=True) or {}
    user_query = str(data.get("query") or "").strip()
    if not user_query:
        return jsonify({"error": "Empty query"}), 400

    mode = str(data.get("mode") or "auto").lower()
    if mode not in ("auto", "local", "global"):
        return jsonify({"error": "mode must be auto, local, or global"}), 400

    kwargs: Dict[str, Any] = {}
    for k in ("n_hop", "max_chunks", "candidate_top_k", "keep_top_k",
              "max_generation_tokens"):
        if k in data:
            try:
                kwargs[k] = int(data[k])
            except (TypeError, ValueError):
                return jsonify({"error": f"{k} must be int"}), 400

    try:
        with _engine_lock:
            engine = _get_engine()
            result = engine.query(user_query=user_query, mode=mode, **kwargs)

        # Normalise / trim for JSON payload
        payload: Dict[str, Any] = {
            "answer": result.get("answer", ""),
            "mode": result.get("mode"),
        }
        if "seeds" in result:
            payload["seeds"] = result["seeds"]
        if "subgraph_nodes" in result:
            payload["subgraph_nodes"] = result["subgraph_nodes"]
        if "chunks" in result:
            payload["chunks"] = [
                {
                    "id": c.get("id"),
                    "text": (c.get("text") or "")[:600],
                    "metadata": {k: str(v) for k, v in (c.get("metadata") or {}).items()},
                }
                for c in result["chunks"]
            ]
        if "communities" in result:
            payload["communities"] = result["communities"]
        if "candidate_count" in result:
            payload["candidate_count"] = result["candidate_count"]
        return jsonify(payload)
    except FileNotFoundError as e:
        return jsonify({"error": str(e), "hint": "call /api/build first"}), 409
    except Exception as e:
        logger.error("Query failed: %s", traceback.format_exc())
        return jsonify({"error": str(e)}), 500


# ── API: Papers (GraphRAG's own database) ────────────────────────────────

@app.route("/api/papers", methods=["GET"])
def list_papers():
    """Return the GraphRAG paper registry (separate from the vector RAG)."""
    return jsonify(_load_registry())


@app.route("/api/papers", methods=["POST"])
def upload_paper():
    """
    Upload a (PDF, Fortran) pair into GraphRAG's database.

    Body: multipart with fields ``pdf`` and ``fortran``.

    The request does NOT auto-rebuild the graph — the caller should hit
    ``POST /api/build`` once all papers are uploaded.
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

    request_tmp_dir = TMP_UPLOAD_DIR / uuid.uuid4().hex
    request_tmp_dir.mkdir(parents=True, exist_ok=True)
    pdf_path = request_tmp_dir / pdf_name
    fortran_path = request_tmp_dir / fortran_name
    pdf_file.save(str(pdf_path))
    fortran_file.save(str(fortran_path))

    try:
        from utils.orchestrator.ingest_paper import ingest_paper_and_code
        from utils.orchestrator.store_to_db import store_ingested_data

        logger.info("[graphRag] ingesting %s + %s", pdf_name, fortran_name)

        ingest_result = ingest_paper_and_code(
            pdf_path=pdf_path,
            fortran_path=fortran_path,
            output_dir=DATA_PATH,
            db_path=str(DB_PATH),
        )

        with _engine_lock:
            # Close any active engine so Qdrant can be reopened as a writer.
            _reload_engine()
            store_result = store_ingested_data(
                ingest_result=ingest_result,
                db_path=DB_PATH,
            )

        return jsonify({
            "status": "ok",
            "message": "Ingested. Rebuild the graph with POST /api/build to reflect this paper.",
            "paper_dir": ingest_result.get("paper_dir", ""),
            "store_result": store_result,
        })
    except Exception as e:
        logger.error("Ingestion failed: %s", traceback.format_exc())
        return jsonify({"error": str(e)}), 500
    finally:
        shutil.rmtree(request_tmp_dir, ignore_errors=True)


@app.route("/api/papers/<path:paper_title>", methods=["DELETE"])
def delete_paper(paper_title: str):
    """Delete a paper's chunks (and profile) from GraphRAG's DB + registry.

    The knowledge graph itself is NOT rebuilt automatically — stale entities
    referencing this paper remain until the next ``POST /api/build``.
    """
    try:
        from utils.s2_embedding.qdrant_store import QdrantVectorStore
        from qdrant_client import models

        with _engine_lock:
            _reload_engine()
            qdrant_dir = str(DB_PATH / "qdrant_data")
            if Path(qdrant_dir).exists():
                # Collect every collection so we hit chunks + profiles.
                for collection in ("rag_embeddings", "paper_profiles"):
                    try:
                        store = QdrantVectorStore(
                            persist_dir=qdrant_dir,
                            collection_name=collection,
                        )
                    except Exception:
                        continue
                    try:
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
                    except Exception as exc:
                        logger.warning("Could not delete from %s: %s", collection, exc)
                    finally:
                        store.close()

            registry = [p for p in _load_registry() if p.get("paper_title") != paper_title]
            _save_registry(registry)

        return jsonify({"status": "ok", "message": f"Deleted '{paper_title}'"})
    except Exception as e:
        logger.error("Delete failed: %s", traceback.format_exc())
        return jsonify({"error": str(e)}), 500


# ── API: Graph / Communities ──────────────────────────────────────────────

@app.route("/api/graph", methods=["GET"])
def dump_graph():
    graph_json = DB_PATH / "graph_rag" / "graph.json"
    if not graph_json.exists():
        return jsonify({"error": "graph not built"}), 404
    with open(graph_json, "r", encoding="utf-8") as f:
        return jsonify(json.load(f))


@app.route("/api/communities", methods=["GET"])
def dump_communities():
    comm_json = DB_PATH / "graph_rag" / "communities.json"
    if not comm_json.exists():
        return jsonify([])
    with open(comm_json, "r", encoding="utf-8") as f:
        return jsonify(json.load(f))


if __name__ == "__main__":
    port = int(os.getenv("PORT", "5000"))
    app.run(host="0.0.0.0", port=port, debug=True)
