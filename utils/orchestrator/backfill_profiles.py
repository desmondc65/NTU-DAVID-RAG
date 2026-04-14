"""
Backfill paper profiles for databases created before the profile index existed.

Reads ``paper_registry.json`` under the given ``db_path``, regenerates a
structured profile for each paper via the LLM, and upserts the results into
the ``paper_profiles`` Qdrant collection.

Usage
-----
    python -m utils.orchestrator.backfill_profiles [--db-path PATH] [--skip-existing]
"""
from __future__ import annotations

import argparse
import hashlib
import json
import logging
import sys
from pathlib import Path

CURRENT_DIR = Path(__file__).resolve().parent
PROJECT_ROOT = CURRENT_DIR.parent.parent
if str(PROJECT_ROOT) not in sys.path:
    sys.path.insert(0, str(PROJECT_ROOT))

from utils.s2_embedding.embedder import EmbeddingModel, _DEFAULT_MODEL
from utils.s2_embedding.qdrant_store import QdrantVectorStore
from utils.llm_clients.local_llm import LocalLLMClient
from utils.orchestrator.paper_profiler import (
    PROFILE_COLLECTION,
    build_paper_profile,
    profile_to_embed_text,
    profile_to_payload,
)

logging.basicConfig(level=logging.INFO, format="%(levelname)s %(name)s | %(message)s")
logger = logging.getLogger("backfill_profiles")


def _existing_profile_ids(store: QdrantVectorStore) -> set:
    """Scroll the profile collection to collect already-indexed IDs."""
    ids: set = set()
    offset = None
    try:
        while True:
            points, next_offset = store.client.scroll(
                collection_name=store.collection_name,
                limit=256,
                offset=offset,
                with_payload=False,
                with_vectors=False,
            )
            for pt in points:
                ids.add(pt.id)
            if next_offset is None:
                break
            offset = next_offset
    except Exception as exc:
        logger.debug("Could not scroll profile collection: %s", exc)
    return ids


def backfill(db_path: Path, skip_existing: bool = True) -> int:
    registry_path = db_path / "paper_registry.json"
    if not registry_path.exists():
        raise FileNotFoundError(f"Paper registry not found: {registry_path}")

    with open(registry_path, "r", encoding="utf-8") as f:
        registry = json.load(f)
    if not registry:
        logger.info("Registry empty — nothing to backfill.")
        return 0

    logger.info("Loading embedder…")
    embedder = EmbeddingModel(model_name=_DEFAULT_MODEL)

    # Probe vector size from the chunk collection if the profile collection
    # doesn't exist yet. Default to 3584 (gte-Qwen2 dim) as a last resort.
    vector_size = 3584
    try:
        sample_embed = embedder.embed_query("probe")
        vector_size = len(sample_embed)
    except Exception:
        pass

    profile_store = QdrantVectorStore(
        persist_dir=str(db_path / "qdrant_data"),
        collection_name=PROFILE_COLLECTION,
        vector_size=vector_size,
    )
    try:
        existing_ids = _existing_profile_ids(profile_store) if skip_existing else set()
        llm = LocalLLMClient()
        built = 0

        for entry in registry:
            title = entry.get("paper_title", "")
            authors = entry.get("authors", "")
            if not title:
                continue

            profile_id = hashlib.md5(f"profile:{title}".encode()).hexdigest()
            if skip_existing and profile_id in existing_ids:
                logger.info("Skipping (already indexed): %s", title)
                continue

            content_list = entry.get("content_list_path", "")
            fortran_digest = entry.get("fortran_digest_path", "")
            if not content_list or not Path(content_list).exists():
                logger.warning("Missing content_list for '%s' — skipping.", title)
                continue

            logger.info("Profiling: %s", title)
            try:
                profile = build_paper_profile(
                    content_list_json=content_list,
                    fortran_digest_json=fortran_digest or None,
                    paper_title=title,
                    authors=authors,
                    llm_client=llm,
                )
            except Exception as exc:
                logger.warning("Profile build failed for '%s': %s", title, exc)
                continue

            embed_text = profile_to_embed_text(profile)
            profile_embedding = embedder.embed_documents([embed_text])[0]
            profile_store.add_documents(
                texts=[embed_text],
                embeddings=[profile_embedding],
                metadatas=[profile_to_payload(profile)],
                ids=[profile_id],
            )
            built += 1
            logger.info("✅ Indexed profile for '%s'", title)
    finally:
        profile_store.close()

    logger.info("Backfill complete — %d profile(s) built.", built)
    return built


def main() -> None:
    parser = argparse.ArgumentParser(description="Backfill paper profiles for an existing Qdrant DB.")
    parser.add_argument(
        "--db-path",
        type=str,
        default=str(PROJECT_ROOT / "db"),
        help="Path to the db directory (contains qdrant_data/ and paper_registry.json).",
    )
    parser.add_argument(
        "--no-skip-existing",
        action="store_true",
        help="Rebuild profiles even if they are already in the profile collection.",
    )
    args = parser.parse_args()

    backfill(
        db_path=Path(args.db_path),
        skip_existing=not args.no_skip_existing,
    )


if __name__ == "__main__":
    main()
