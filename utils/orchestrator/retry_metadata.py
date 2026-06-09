"""
Re-run title/author extraction for a paper already in the database.

Scenario: the ingest-time LLM call returned empty or wrong ``paper_title`` /
``authors``. Re-running the full ingestion would re-download, re-extract,
and re-embed the whole paper. Instead, this module:

1. Loads the paper's existing ``metadata.json``.
2. Calls :func:`extract_paper_metadata` again on the saved markdown.
3. If a non-empty new title is produced, propagates it through every
   artefact that cached the old (empty / wrong) value:

   - ``metadata.json``
   - ``<stem>_content_list.json``  (top-level ``paper_title`` + ``authors``)
   - ``<stem>_digest.json``        (Fortran digest — same fields)
   - ``db/paper_registry.json``
   - Qdrant ``rag_embeddings``   — ``paper_title`` + ``authors`` payloads
   - Qdrant ``paper_profiles``   — ditto (if the collection exists)

Filesystem layout (paper directory name, ``source_file`` paths inside
Qdrant payloads) is intentionally NOT rewritten by this routine — renaming
cascades through dozens of cached absolute paths and is better done with
a dedicated tool. Call sites can simply read the updated title from the
registry / payloads.

CLI
---
    python -m utils.orchestrator.retry_metadata \
        --db-path /app/db --paper-dir /app/data/untitled-paper
    python -m utils.orchestrator.retry_metadata \
        --db-path /app/db --paper-title ""        # matches a single untitled paper
"""
from __future__ import annotations

import argparse
import json
import logging
import sys
from pathlib import Path
from typing import Any, Dict, List, Optional, Union

CURRENT_DIR = Path(__file__).resolve().parent
PROJECT_ROOT = CURRENT_DIR.parent.parent
if str(PROJECT_ROOT) not in sys.path:
    sys.path.insert(0, str(PROJECT_ROOT))

from qdrant_client import models  # noqa: E402

from utils.orchestrator.ingest_paper import extract_paper_metadata  # noqa: E402
from utils.s2_embedding.qdrant_store import QdrantVectorStore  # noqa: E402
from utils.s2_embedding.collections import (  # noqa: E402
    CHUNK_COLLECTION_BASE,
    PROFILE_COLLECTION_BASE,
    matching_collections,
)

logger = logging.getLogger(__name__)

# Bases shared with the rest of the stack. A paper may have been ingested under
# more than one embedder (each writes to `<base>__<tag>` collections), so the
# rename below sweeps every matching collection, not just these bare names.
MAIN_COLLECTION = CHUNK_COLLECTION_BASE
PROFILE_COLLECTION = PROFILE_COLLECTION_BASE


# ── JSON helpers ────────────────────────────────────────────────────────

def _load_json(path: Path) -> Any:
    with open(path, "r", encoding="utf-8") as f:
        return json.load(f)


def _dump_json(path: Path, data: Any) -> None:
    with open(path, "w", encoding="utf-8") as f:
        json.dump(data, f, indent=4, ensure_ascii=False)


def _update_embedded_metadata(json_path: Path, new_title: str, new_authors: str) -> bool:
    """Inject ``paper_title`` / ``authors`` at the top level of a JSON file.

    Handles both object and raw-list layouts (the content-list JSON is
    wrapped into ``{"items": [...]}`` if it was a bare list).
    Returns True when the file was rewritten.
    """
    if not json_path.exists():
        return False
    data = _load_json(json_path)
    if isinstance(data, list):
        data = {"paper_title": new_title, "authors": new_authors, "items": data}
    elif isinstance(data, dict):
        data["paper_title"] = new_title
        data["authors"] = new_authors
    else:
        return False
    _dump_json(json_path, data)
    return True


# ── Registry ────────────────────────────────────────────────────────────

def _update_registry(
    registry_path: Path,
    old_title: str,
    content_list_path: str,
    new_title: str,
    new_authors: str,
) -> bool:
    if not registry_path.exists():
        return False
    entries = _load_json(registry_path)
    if not isinstance(entries, list):
        return False
    changed = False
    for entry in entries:
        # Match on (old_title, content_list_path) so we only touch the one
        # affected paper — multiple "untitled" rows would collide on title
        # alone.
        if (
            str(entry.get("paper_title", "")) == old_title
            and str(entry.get("content_list_path", "")) == content_list_path
        ):
            entry["paper_title"] = new_title
            entry["authors"] = new_authors
            changed = True
            break
    if changed:
        _dump_json(registry_path, entries)
    return changed


# ── Qdrant ──────────────────────────────────────────────────────────────

def _filter_by(key: str, value: str) -> "models.Filter":
    return models.Filter(
        must=[models.FieldCondition(key=key, match=models.MatchValue(value=value))]
    )


def _list_collection_names(qdrant_dir: Path) -> List[str]:
    """List collection names in the store (empty list if it can't be opened)."""
    try:
        store = QdrantVectorStore(
            persist_dir=str(qdrant_dir),
            collection_name=MAIN_COLLECTION,
            manage_schema=False,
        )
    except Exception as exc:
        logger.warning("Cannot open Qdrant store at %s: %s", qdrant_dir, exc)
        return []
    try:
        return [c.name for c in store.client.get_collections().collections]
    except Exception as exc:
        logger.warning("Cannot list Qdrant collections: %s", exc)
        return []
    finally:
        store.close()


def _update_qdrant_collection(
    qdrant_dir: Path,
    collection: str,
    old_title: str,
    old_source_files: List[str],
    new_title: str,
    new_authors: str,
) -> int:
    """Update ``paper_title`` + ``authors`` on every point matching the old paper.

    Filters tried in order until one yields a non-zero match:

    1. ``paper_title == old_title``  (when old_title is non-empty)
    2. ``source_file == <each of old_source_files>``  (stable identifier)
    3. ``paper_title == ""``         (only for the profile collection, which
       holds one synthetic point per paper and has no ``source_file``)

    Returns the total number of points updated.
    """
    try:
        # Payload-only update — never create or dimension-check the collection
        # (vector size is unknown here and irrelevant to a payload write).
        store = QdrantVectorStore(
            persist_dir=str(qdrant_dir), collection_name=collection, manage_schema=False
        )
    except Exception as exc:
        logger.warning("Cannot open Qdrant collection %r: %s", collection, exc)
        return 0

    try:
        collections = {c.name for c in store.client.get_collections().collections}
        if collection not in collections:
            return 0

        filters: List["models.Filter"] = []
        if old_title:
            filters.append(_filter_by("paper_title", old_title))
        for sf in old_source_files:
            if sf:
                filters.append(_filter_by("source_file", sf))
        is_profile = collection == PROFILE_COLLECTION or collection.startswith(
            f"{PROFILE_COLLECTION}__"
        )
        if is_profile and not old_title:
            # The profile collection doesn't carry source_file on its
            # synthetic point, and an untitled paper's payload still has
            # paper_title=="" — match that directly.
            filters.append(_filter_by("paper_title", ""))

        total_updated = 0
        for flt in filters:
            try:
                count = store.client.count(
                    collection_name=collection, count_filter=flt, exact=True
                ).count
            except Exception as exc:
                logger.debug("count failed on %r (%s) — skipping filter", collection, exc)
                continue
            if count == 0:
                continue
            store.client.set_payload(
                collection_name=collection,
                payload={"paper_title": new_title, "authors": new_authors},
                points=flt,
            )
            total_updated += count
        return total_updated
    finally:
        store.close()


# ── Main entry point ────────────────────────────────────────────────────

def retry_paper_metadata(
    db_path: Union[str, Path],
    paper_dir: Union[str, Path],
) -> Dict[str, Any]:
    """
    Re-run LLM title/author extraction for one paper and propagate the
    result through every derived artefact. See module docstring.

    Raises
    ------
    FileNotFoundError
        If ``paper_dir/metadata.json`` or the manuscript markdown is missing.
    RuntimeError
        If the LLM still returns an empty title — cannot safely update.
    """
    db_path = Path(db_path)
    paper_dir = Path(paper_dir)

    metadata_path = paper_dir / "metadata.json"
    if not metadata_path.exists():
        raise FileNotFoundError(f"metadata.json not found in {paper_dir}")

    meta = _load_json(metadata_path)
    old_title = str(meta.get("paper_title", "") or "")
    old_authors = str(meta.get("authors", "") or "")
    md_path = str(meta.get("md_path", "") or "")
    content_list_path = str(meta.get("content_list_path", "") or "")
    fortran_digest_path = str(meta.get("fortran_digest_path", "") or "")

    if not md_path or not Path(md_path).exists():
        raise FileNotFoundError(f"Manuscript markdown missing: {md_path!r}")

    logger.info("Retrying metadata extraction for %r in %s", old_title, paper_dir)
    result = extract_paper_metadata(md_path=md_path)
    new_title = str(result.get("paper_title", "") or "").strip()
    new_authors = str(result.get("authors", "") or "").strip()

    if not new_title:
        raise RuntimeError(
            "LLM still returned an empty paper_title — refusing to overwrite. "
            "Check the manuscript markdown and LLM connectivity."
        )

    if new_title == old_title and new_authors == old_authors:
        logger.info("New metadata identical to old — no changes applied.")
        return {
            "old_title": old_title,
            "old_authors": old_authors,
            "new_title": new_title,
            "new_authors": new_authors,
            "points_updated_main": 0,
            "points_updated_profile": 0,
            "registry_updated": False,
            "paper_dir": str(paper_dir),
            "changed": False,
        }

    # ── Propagate to embedded JSON files ────────────────────────────────
    content_list_updated = _update_embedded_metadata(
        Path(content_list_path), new_title, new_authors
    ) if content_list_path else False
    fortran_digest_updated = _update_embedded_metadata(
        Path(fortran_digest_path), new_title, new_authors
    ) if fortran_digest_path else False

    # ── metadata.json ───────────────────────────────────────────────────
    meta["paper_title"] = new_title
    meta["authors"] = new_authors
    _dump_json(metadata_path, meta)

    # ── Qdrant payloads ─────────────────────────────────────────────────
    # Both manuscript chunks and Fortran chunks carry a ``source_file``
    # pointing at their ingest JSON. Pass both so the filter matches all
    # of this paper's points even when ``old_title`` was empty.
    qdrant_dir = db_path / "qdrant_data"
    old_source_files = [p for p in (content_list_path, fortran_digest_path) if p]

    # The paper may live in several per-embedder collections (rag_embeddings,
    # rag_embeddings__<tag>, …). Update every one so the rename is consistent
    # regardless of which embedder ingested it.
    existing = _list_collection_names(qdrant_dir)
    points_main = sum(
        _update_qdrant_collection(
            qdrant_dir, coll,
            old_title=old_title, old_source_files=old_source_files,
            new_title=new_title, new_authors=new_authors,
        )
        for coll in matching_collections(existing, MAIN_COLLECTION)
    )
    points_profile = sum(
        _update_qdrant_collection(
            qdrant_dir, coll,
            old_title=old_title, old_source_files=old_source_files,
            new_title=new_title, new_authors=new_authors,
        )
        for coll in matching_collections(existing, PROFILE_COLLECTION)
    )

    # ── Registry ────────────────────────────────────────────────────────
    registry_updated = _update_registry(
        db_path / "paper_registry.json",
        old_title=old_title,
        content_list_path=content_list_path,
        new_title=new_title,
        new_authors=new_authors,
    )

    summary = {
        "old_title": old_title,
        "old_authors": old_authors,
        "new_title": new_title,
        "new_authors": new_authors,
        "content_list_updated": content_list_updated,
        "fortran_digest_updated": fortran_digest_updated,
        "points_updated_main": int(points_main),
        "points_updated_profile": int(points_profile),
        "registry_updated": registry_updated,
        "paper_dir": str(paper_dir),
        "changed": True,
    }
    logger.info("Retry complete: %s", summary)
    return summary


# ── Paper-dir resolution helper (shared with Flask endpoint) ────────────

def resolve_paper_dir(
    db_path: Union[str, Path],
    *,
    paper_title: Optional[str] = None,
    paper_dir: Optional[Union[str, Path]] = None,
    data_root: Optional[Union[str, Path]] = None,
) -> Path:
    """
    Resolve the paper directory from either an explicit path or a title
    lookup in the registry. Raises ``FileNotFoundError`` when nothing
    matches and ``ValueError`` when the title is ambiguous.
    """
    if paper_dir:
        p = Path(paper_dir)
        if not p.is_absolute() and data_root is not None:
            p = Path(data_root) / p
        if not (p / "metadata.json").exists():
            raise FileNotFoundError(f"No metadata.json in {p}")
        return p

    if paper_title is None:
        raise ValueError("Provide paper_title or paper_dir.")

    registry_path = Path(db_path) / "paper_registry.json"
    if not registry_path.exists():
        raise FileNotFoundError(f"Registry missing at {registry_path}")
    entries = _load_json(registry_path)
    hits = [e for e in entries if str(e.get("paper_title", "")) == paper_title]
    if not hits:
        raise FileNotFoundError(f"No paper with title {paper_title!r} in registry")
    if len(hits) > 1:
        raise ValueError(
            f"Multiple papers with title {paper_title!r} — pass paper_dir to disambiguate."
        )
    content_list_path = str(hits[0].get("content_list_path", "") or "")
    if not content_list_path:
        raise ValueError("Registry entry missing content_list_path.")
    # Expected layout: <paper_dir>/ingest_output/<stem>/auto/<stem>_content_list.json
    p = Path(content_list_path).parents[3]
    if not (p / "metadata.json").exists():
        raise FileNotFoundError(f"metadata.json missing in inferred paper dir {p}")
    return p


# ── CLI ─────────────────────────────────────────────────────────────────

def _cli() -> int:
    parser = argparse.ArgumentParser(description="Retry title/author extraction for a paper in the RAG database.")
    parser.add_argument("--db-path", default=str(PROJECT_ROOT / "db"))
    parser.add_argument(
        "--paper-dir",
        default=None,
        help="Path to the paper directory containing metadata.json.",
    )
    parser.add_argument(
        "--paper-title",
        default=None,
        help="Current paper_title in the registry (use \"\" for untitled).",
    )
    parser.add_argument("--verbose", action="store_true")
    args = parser.parse_args()

    logging.basicConfig(
        level=logging.DEBUG if args.verbose else logging.INFO,
        format="%(levelname)s %(name)s | %(message)s",
    )

    try:
        paper_dir = resolve_paper_dir(
            db_path=args.db_path,
            paper_title=args.paper_title,
            paper_dir=args.paper_dir,
        )
    except (FileNotFoundError, ValueError) as exc:
        logger.error("%s", exc)
        return 2

    try:
        summary = retry_paper_metadata(db_path=args.db_path, paper_dir=paper_dir)
    except Exception as exc:
        logger.error("Retry failed: %s", exc)
        return 1

    print(json.dumps(summary, indent=2, ensure_ascii=False))
    return 0


if __name__ == "__main__":
    sys.exit(_cli())
