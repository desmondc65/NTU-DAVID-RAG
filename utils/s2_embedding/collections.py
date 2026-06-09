"""
Per-embedding-model Qdrant collection naming.

A Qdrant collection has a fixed vector dimension, so two embedders that emit
different-dimension vectors (e.g. gte-Qwen2-7B → 3584-dim vs
embeddinggemma-300m → 768-dim) cannot share one collection. To let several
embedders' vectors coexist in a single on-disk store — so switching models no
longer means wiping and re-ingesting — each model gets its own pair of
collections, derived from its identity:

    chunks    rag_embeddings__<tag>
    profiles  paper_profiles__<tag>

where ``<tag>`` is a sanitized form of the model id, e.g.::

    google/embeddinggemma-300m         -> embeddinggemma-300m
    Alibaba-NLP/gte-Qwen2-7B-instruct  -> gte-qwen2-7b-instruct

Backward compatibility
-----------------------
The historical default model keeps the un-suffixed legacy names
(``rag_embeddings`` / ``paper_profiles``) so existing populated stores keep
working with no migration. Every other model is suffixed. Set
``RAG_COLLECTION_LEGACY_ALIAS=false`` to suffix the default model too (fresh
stores only — this changes the names existing data lives under).

Active-model resolution (remote-mode aware)
-------------------------------------------
In the Docker stack the embedder runs behind an HTTP server, so the backend
never loads it locally and can't read the model id off a local object. It is
resolved, in order, from:

  1. ``RAG_COLLECTION_MODEL`` env   — explicit override, naming only
  2. ``EMBEDDING_MODEL`` env        — what the embedding server was told to load
  3. ``GET {RAG_EMBEDDING_SERVER_URL}/info`` — best-effort, cached per URL
  4. the default model
"""
from __future__ import annotations

import os
import re
from typing import Optional, Tuple

from utils.s2_embedding.embedder import _DEFAULT_MODEL

# Base names. The legacy (un-suffixed) values match what pre-namespacing
# stores already use, which is why the default model aliases onto them.
CHUNK_COLLECTION_BASE = "rag_embeddings"
PROFILE_COLLECTION_BASE = "paper_profiles"

# Cache of {server_url: model_name} so we hit /info at most once per URL.
_info_cache: dict = {}


def model_tag(model_name: str) -> str:
    """Sanitize a model id into a collection-safe tag (last path segment)."""
    base = (model_name or "").strip().rstrip("/")
    base = base.split("/")[-1].lower()
    base = re.sub(r"[^a-z0-9]+", "-", base).strip("-")
    return base or "model"


def _legacy_alias_enabled() -> bool:
    return os.getenv("RAG_COLLECTION_LEGACY_ALIAS", "true").strip().lower() not in (
        "0",
        "false",
        "no",
        "off",
    )


def _is_legacy_default(model_name: str) -> bool:
    return _legacy_alias_enabled() and model_tag(model_name) == model_tag(_DEFAULT_MODEL)


def collection_names(
    model_name: str,
    base_chunk: str = CHUNK_COLLECTION_BASE,
    base_profile: str = PROFILE_COLLECTION_BASE,
) -> Tuple[str, str]:
    """Return ``(chunk_collection, profile_collection)`` for ``model_name``.

    The default model maps to the un-suffixed ``base_chunk`` / ``base_profile``
    (legacy alias); any other model gets a ``__<tag>`` suffix.
    """
    if _is_legacy_default(model_name):
        return base_chunk, base_profile
    tag = model_tag(model_name)
    return f"{base_chunk}__{tag}", f"{base_profile}__{tag}"


def resolve_embedding_model(explicit: Optional[str] = None) -> str:
    """Resolve the active embedding model id (see module docstring for order)."""
    if explicit and explicit.strip():
        return explicit.strip()

    for var in ("RAG_COLLECTION_MODEL", "EMBEDDING_MODEL"):
        val = os.getenv(var)
        if val and val.strip():
            return val.strip()

    server = os.getenv("RAG_EMBEDDING_SERVER_URL", "").strip().rstrip("/")
    if server:
        if server in _info_cache:
            return _info_cache[server]
        try:
            import requests

            resp = requests.get(f"{server}/info", timeout=5)
            resp.raise_for_status()
            name = (resp.json() or {}).get("embedding_model")
            if name:
                _info_cache[server] = name
                return name
        except Exception:
            # Best-effort only — fall through to the default below.
            pass

    return _DEFAULT_MODEL


def collections_for_active_model(
    explicit: Optional[str] = None,
    base_chunk: str = CHUNK_COLLECTION_BASE,
    base_profile: str = PROFILE_COLLECTION_BASE,
) -> Tuple[str, str]:
    """Convenience: resolve the active model then return its collection names."""
    return collection_names(
        resolve_embedding_model(explicit), base_chunk=base_chunk, base_profile=base_profile
    )


def matching_collections(existing: list, base: str) -> list:
    """Filter ``existing`` collection names to those owned by ``base``.

    Matches the legacy un-suffixed name and every ``<base>__<tag>`` variant —
    used by cross-cutting maintenance ops (delete, metadata rename) that must
    touch a paper wherever it was ingested, under any embedder.
    """
    prefix = f"{base}__"
    return [n for n in existing if n == base or n.startswith(prefix)]
