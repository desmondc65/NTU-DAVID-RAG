"""
Shared embedding + reranker HTTP service.

Loads the embedding model (default Alibaba-NLP/gte-Qwen2-7B-instruct) and
the cross-encoder reranker (default BAAI/bge-reranker-v2-m3) once on
startup, then serves the RAG backend over HTTP so the 7B embedder
occupies only one GPU slot across the stack.

Endpoints
---------
GET  /health                — readiness probe.
GET  /info                  — model identities, embedding dimension.
POST /embed/query           — {"query": "..."} → {"embedding": [...]}
POST /embed/documents       — {"texts": [...], "batch_size": 8} → {"embeddings": [[...]]}
POST /rerank                — {"query": "...", "passages": [...]} → {"scores": [...]}

Design notes
------------
* Query/passage instruction prefixes are applied server-side — clients
  send raw text. This means the server, not the client, owns the
  embedder's asymmetric-retrieval behaviour.
* The reranker returns scores aligned with the input ``passages`` order.
  Sorting / top-k is the caller's responsibility (kept in
  ``utils.s3_RAG.reranker.Reranker.rerank``).
"""
from __future__ import annotations

import logging
import os
import sys
from pathlib import Path
from threading import Lock
from typing import Any, Dict, List

# Make the `utils` package importable — it's mounted at /app/utils by the
# unified docker-compose. Prepend explicitly because gunicorn workers do
# not always include CWD in sys.path depending on invocation.
_PROJECT_ROOT = Path(__file__).resolve().parent
if str(_PROJECT_ROOT) not in sys.path:
    sys.path.insert(0, str(_PROJECT_ROOT))

from flask import Flask, jsonify, request

# Reuse the prefix logic from the existing embedder wrapper so server
# and standalone clients apply identical text before encoding.
from utils.s2_embedding.embedder import (
    _doc_prefix,
    _query_prefix,
    _DEFAULT_MODEL as _DEFAULT_EMBEDDING_MODEL,
)

logging.basicConfig(level=logging.INFO, format="%(levelname)s %(name)s | %(message)s")
logger = logging.getLogger("embedding-server")


EMBEDDING_MODEL_NAME = os.getenv("EMBEDDING_MODEL", _DEFAULT_EMBEDDING_MODEL)
RERANKER_MODEL_NAME = os.getenv("RERANKER_MODEL", "BAAI/bge-reranker-v2-m3")
EMBEDDING_DEVICE = os.getenv("EMBEDDING_DEVICE", "cuda:0")
RERANKER_DEVICE = os.getenv("RERANKER_DEVICE", EMBEDDING_DEVICE)
# When set (e.g. "auto"), the embedder is loaded with HF Accelerate's
# device_map so its layers shard across every visible CUDA device. Lets
# the 7B model fit when no single GPU has enough free memory on its own.
EMBEDDING_DEVICE_MAP = os.getenv("EMBEDDING_DEVICE_MAP") or None
DEFAULT_BATCH_SIZE = int(os.getenv("EMBEDDING_BATCH_SIZE", "8"))


app = Flask(__name__)

_embedder = None
_reranker = None
_embed_lock = Lock()
_rerank_lock = Lock()

_query_pref = _query_prefix(EMBEDDING_MODEL_NAME)
_doc_pref = _doc_prefix(EMBEDDING_MODEL_NAME)


def _load_models() -> None:
    """Load models into GPU memory. Called once at startup."""
    global _embedder, _reranker
    import torch  # needed for the fp16 dtype handle below

    from sentence_transformers import SentenceTransformer, CrossEncoder

    if EMBEDDING_DEVICE_MAP:
        # device_map drives placement; passing `device=` would trigger an
        # extra .to() that conflicts with the dispatched layout. Note:
        # gte-Qwen2-7B's custom modeling code (trust_remote_code) has
        # been observed to break at inference under multi-GPU sharding
        # ("tensors on cuda:0 and cuda:1") because its custom RMSNorm
        # doesn't carry Accelerate's cross-device hooks. Prefer the
        # single-GPU fp16 path below unless you've verified your model
        # variant works.
        logger.info(
            "Loading embedding model '%s' with device_map='%s' (fp16) …",
            EMBEDDING_MODEL_NAME,
            EMBEDDING_DEVICE_MAP,
        )
        _embedder = SentenceTransformer(
            EMBEDDING_MODEL_NAME,
            model_kwargs={
                "device_map": EMBEDDING_DEVICE_MAP,
                "torch_dtype": torch.float16,
            },
            trust_remote_code=True,
        )
    else:
        # fp16 on a single GPU: ~14 GB for the 7B model, comfortably
        # below a 48 GB card even with neighbour jobs eating ~25 GB.
        logger.info(
            "Loading embedding model '%s' on %s (fp16) …",
            EMBEDDING_MODEL_NAME,
            EMBEDDING_DEVICE,
        )
        _embedder = SentenceTransformer(
            EMBEDDING_MODEL_NAME,
            device=EMBEDDING_DEVICE,
            model_kwargs={"torch_dtype": torch.float16},
            trust_remote_code=True,
        )
    logger.info("Embedding model ready.")

    logger.info("Loading reranker '%s' on %s …", RERANKER_MODEL_NAME, RERANKER_DEVICE)
    _reranker = CrossEncoder(RERANKER_MODEL_NAME, device=RERANKER_DEVICE)
    logger.info("Reranker ready.")


def _ensure_embedder():
    if _embedder is None:
        raise RuntimeError("Embedding model not loaded yet.")
    return _embedder


def _ensure_reranker():
    if _reranker is None:
        raise RuntimeError("Reranker not loaded yet.")
    return _reranker


# ── Endpoints ─────────────────────────────────────────────────────────────

@app.route("/health", methods=["GET"])
def health():
    return jsonify(
        {
            "status": "ok" if (_embedder is not None and _reranker is not None) else "loading",
            "embedder_ready": _embedder is not None,
            "reranker_ready": _reranker is not None,
        }
    )


@app.route("/info", methods=["GET"])
def info():
    dim = None
    try:
        if _embedder is not None:
            dim = int(_embedder.get_sentence_embedding_dimension())
    except Exception:
        pass
    return jsonify(
        {
            "embedding_model": EMBEDDING_MODEL_NAME,
            "reranker_model": RERANKER_MODEL_NAME,
            "embedding_dim": dim,
            "embedding_device": EMBEDDING_DEVICE_MAP or EMBEDDING_DEVICE,
            "embedding_device_map": EMBEDDING_DEVICE_MAP,
            "reranker_device": RERANKER_DEVICE,
        }
    )


@app.route("/embed/query", methods=["POST"])
def embed_query():
    body: Dict[str, Any] = request.get_json(silent=True) or {}
    query = body.get("query")
    if not isinstance(query, str) or not query:
        return jsonify({"error": "query must be a non-empty string"}), 400

    text = f"{_query_pref}{query}" if _query_pref else query
    with _embed_lock:
        embedder = _ensure_embedder()
        emb = embedder.encode([text], normalize_embeddings=True)
    return jsonify({"embedding": emb[0].tolist()})


@app.route("/embed/documents", methods=["POST"])
def embed_documents():
    body: Dict[str, Any] = request.get_json(silent=True) or {}
    texts = body.get("texts")
    if not isinstance(texts, list) or not all(isinstance(t, str) for t in texts):
        return jsonify({"error": "texts must be a list of strings"}), 400
    if not texts:
        return jsonify({"embeddings": []})

    batch_size = body.get("batch_size", DEFAULT_BATCH_SIZE)
    try:
        batch_size = int(batch_size)
    except (TypeError, ValueError):
        return jsonify({"error": "batch_size must be int"}), 400

    prepared: List[str] = (
        [f"{_doc_pref}{t}" for t in texts] if _doc_pref else list(texts)
    )
    with _embed_lock:
        embedder = _ensure_embedder()
        emb = embedder.encode(
            prepared,
            batch_size=batch_size,
            show_progress_bar=False,
            normalize_embeddings=True,
        )
    return jsonify({"embeddings": emb.tolist()})


@app.route("/rerank", methods=["POST"])
def rerank():
    body: Dict[str, Any] = request.get_json(silent=True) or {}
    query = body.get("query")
    passages = body.get("passages")
    if not isinstance(query, str) or not query:
        return jsonify({"error": "query must be a non-empty string"}), 400
    if not isinstance(passages, list) or not all(isinstance(p, str) for p in passages):
        return jsonify({"error": "passages must be a list of strings"}), 400
    if not passages:
        return jsonify({"scores": []})

    pairs = [(query, p) for p in passages]
    with _rerank_lock:
        reranker = _ensure_reranker()
        scores = reranker.predict(pairs, show_progress_bar=False)
    return jsonify({"scores": [float(s) for s in scores]})


# ── Startup ───────────────────────────────────────────────────────────────
# Load models eagerly so the first request is fast. With gunicorn
# --preload, this runs once per worker process.
_load_models()


if __name__ == "__main__":
    port = int(os.getenv("PORT", "8080"))
    app.run(host="0.0.0.0", port=port, debug=False)
