"""
Orchestrator: chunk ingested data, embed, and store into Qdrant.

Takes the output dict from ``ingest_paper_and_code`` (paths to the
content-list JSON, Fortran-digest JSON, and metadata JSON), chunks the
content, embeds everything, and upserts into a Qdrant collection.

Also maintains a paper registry (``paper_registry.json``) that tracks
which papers are currently in the database — useful for frontend display.
"""
from __future__ import annotations

import hashlib
import json
import logging
import os
import re
import sys
import time
from datetime import datetime, timezone
from pathlib import Path
from typing import Dict, List, Optional, Union

from dotenv import load_dotenv

load_dotenv()

# ── path setup ────────────────────────────────────────────────────────────
CURRENT_DIR = Path(__file__).resolve().parent
PROJECT_ROOT = CURRENT_DIR.parent.parent

if str(PROJECT_ROOT) not in sys.path:
    sys.path.insert(0, str(PROJECT_ROOT))

from utils.s2_embedding.embedder import EmbeddingModel, _DEFAULT_MODEL
from utils.s2_embedding.qdrant_store import QdrantVectorStore

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)


# ── helpers ───────────────────────────────────────────────────────────────

def _estimate_tokens(text: str) -> int:
    """Rough token estimate: ~0.75 tokens per whitespace-delimited word."""
    return int(len(text.split()) * 1.33)


def _make_id(content_type: str, source: str, index: int) -> str:
    """Generate a deterministic document ID."""
    raw = f"{content_type}:{source}:{index}"
    return hashlib.md5(raw.encode()).hexdigest()


def _is_section_heading(item: dict) -> bool:
    """Check if a content-list item is a section heading (has text_level)."""
    return "text_level" in item


def _heading_depth(text: str) -> int:
    """Infer heading depth from academic paper text patterns.

    Returns 1 for major sections (Roman numerals, Appendix),
    2 for subsections (A., B., etc.), 0 for unrecognised.
    """
    stripped = text.strip()
    if re.match(r'^[IVX]+\.\s', stripped):
        return 1
    if re.match(r'^Appendix\b', stripped, re.IGNORECASE):
        return 1
    if re.match(r'^[A-Z]\.\s', stripped):
        return 2
    return 0


# ── manuscript chunking ──────────────────────────────────────────────────

def chunk_content_list(
    json_path: Union[str, Path],
    max_tokens: int = 384,
    overlap_tokens: int = 64,
) -> List[Dict]:
    """
    Chunk a content-list JSON produced by ``ingest_paper_and_code``.

    The JSON has top-level keys ``paper_title``, ``authors``, ``items``.
    Items have ``type`` in {text, image, equation, table, discarded}.

    - **text** items with ``text_level`` are treated as **section headings**:
      they mark chunk boundaries and provide hierarchical section context.
    - **text** items without ``text_level`` are merged and chunked with overlap.
    - **image / equation / table** items become one document each,
      using ``description`` as the index key for RAG.
    - **discarded** items are skipped.

    Section context (e.g. ``[Section: III. Model > A. Environment]``) is
    prepended to every chunk for better embedding relevance.

    Each returned dict has ``text`` (the index key) and ``metadata``.
    ``sequence_idx`` preserves the original ordering in the JSON.
    """
    json_path = Path(json_path)
    with open(json_path, "r", encoding="utf-8") as f:
        data = json.load(f)

    paper_title = data.get("paper_title", "")
    authors = data.get("authors", "")
    items = data.get("items", data if isinstance(data, list) else [])

    # Resolve image base dir (images/ is relative to the JSON file)
    images_base = json_path.parent

    chunks: List[Dict] = []

    # ── Pass 1: collect all non-discarded items with their sequence index ─
    entries = []
    for seq_idx, item in enumerate(items):
        item_type = item.get("type", "")
        if item_type == "discarded":
            continue
        entries.append((seq_idx, item))

    # ── Section tracking ────────────────────────────────────────────────
    section_path: List[str] = []   # hierarchical breadcrumb

    def _current_section() -> str:
        return " > ".join(section_path) if section_path else ""

    # ── Pass 2: process by type ──────────────────────────────────────────

    # Buffer for merging consecutive text items
    text_buffer: List[str] = []
    text_tokens = 0
    text_pages: set = set()
    text_seq_indices: List[int] = []
    chunk_idx = 0

    def _flush_text(at_section_boundary: bool = False):
        nonlocal chunk_idx, text_buffer, text_tokens, text_pages, text_seq_indices
        if not text_buffer:
            return

        merged = "\n\n".join(text_buffer)
        section = _current_section()

        # Prepend section context for better embedding relevance
        embed_text = f"[Section: {section}]\n\n{merged}" if section else merged

        chunks.append({
            "text": embed_text,
            "metadata": {
                "paper_title": paper_title,
                "authors": authors,
                "content_type": "manuscript",
                "section": section,
                "page_indices": str(sorted(text_pages)),
                "chunk_idx": chunk_idx,
                "sequence_idx": text_seq_indices[0],  # first item in chunk
                "source_file": str(json_path),
            },
        })
        chunk_idx += 1

        # No overlap across section boundaries — context changes too much
        if at_section_boundary:
            text_buffer = []
            text_tokens = 0
            text_pages = set()
            text_seq_indices = []
            return

        # Overlap: keep trailing text that fits within overlap_tokens
        overlap_texts = []
        overlap_tok = 0
        overlap_seqs = []
        for t, s in zip(reversed(text_buffer), reversed(text_seq_indices)):
            t_tok = _estimate_tokens(t)
            if overlap_tok + t_tok > overlap_tokens:
                break
            overlap_texts.insert(0, t)
            overlap_seqs.insert(0, s)
            overlap_tok += t_tok

        text_buffer = overlap_texts
        text_tokens = overlap_tok
        text_pages = set()
        text_seq_indices = overlap_seqs

    for seq_idx, item in entries:
        item_type = item.get("type", "")

        if item_type == "text":
            text = item.get("text", "").strip()
            if not text:
                continue

            # Section headings: flush buffer and update section path
            if _is_section_heading(item):
                _flush_text(at_section_boundary=True)
                depth = _heading_depth(text)
                if depth == 1:
                    section_path = [text]
                elif depth == 2:
                    section_path = section_path[:1] + [text]
                else:
                    # Has text_level but unrecognised pattern — new top section
                    section_path = [text]
                continue

            entry_tokens = _estimate_tokens(text)
            page_idx = item.get("page_idx", -1)

            if text_tokens + entry_tokens > max_tokens and text_buffer:
                _flush_text()

            text_buffer.append(text)
            text_tokens += entry_tokens
            text_pages.add(page_idx)
            text_seq_indices.append(seq_idx)

        elif item_type in ("image", "equation", "table"):
            # Flush any pending text first to preserve ordering
            _flush_text()

            description = item.get("description", "")
            if not description:
                continue  # nothing to index

            section = _current_section()

            meta = {
                "paper_title": paper_title,
                "authors": authors,
                "content_type": item_type,
                "section": section,
                "sequence_idx": seq_idx,
                "page_idx": item.get("page_idx", -1),
                "source_file": str(json_path),
            }

            if item_type == "image":
                img_path = item.get("img_path", "")
                if img_path:
                    absolute_img_path = images_base / img_path
                    meta["img_path"] = str(absolute_img_path)
                    paper_dir = data.get("paper_dir", "")
                    if paper_dir:
                        try:
                            meta["img_rel_path"] = str(absolute_img_path.relative_to(Path(paper_dir)))
                        except Exception:
                            meta["img_rel_path"] = str(img_path)

            if item_type == "table":
                meta["table_caption"] = str(item.get("table_caption", ""))
                meta["table_body"] = item.get("table_body", "")

            if item_type == "equation":
                meta["equation_latex"] = item.get("text", "")

            # Prepend section context for non-text items too
            embed_text = f"[Section: {section}]\n\n{description}" if section else description

            chunks.append({
                "text": embed_text,
                "metadata": meta,
            })

    # Flush remaining text
    _flush_text()

    logger.info(
        "Chunked content list: %d documents (%d text chunks + non-text items)",
        len(chunks), chunk_idx,
    )
    return chunks


# ── fortran digest processing ────────────────────────────────────────────

def chunk_fortran_digest(
    json_path: Union[str, Path],
) -> List[Dict]:
    """
    Process a Fortran digest JSON into documents for RAG.

    Uses the new structure-aware digest format:
    - ``composite_text`` as the embedding text (combines name, purpose,
      economic concepts, call graph, and algorithm summary).
    - ``architecture_overview`` becomes a special document for broad queries.
    - Falls back to old ``summary_index`` format for backward compatibility.
    """
    json_path = Path(json_path)
    with open(json_path, "r", encoding="utf-8") as f:
        data = json.load(f)

    paper_title = data.get("paper_title", "")
    authors = data.get("authors", "")
    functions = data.get("key_functions", [])

    chunks: List[Dict] = []

    # Architecture overview document (new format)
    arch_overview = data.get("architecture_overview", "")
    if arch_overview:
        chunks.append({
            "text": arch_overview,
            "metadata": {
                "paper_title": paper_title,
                "authors": authors,
                "content_type": "fortran_architecture",
                "function_name": "_architecture_overview",
                "purpose": "Global overview of the Fortran program structure and computational pipeline",
                "source_file": str(json_path),
                "sequence_idx": -1,
            },
        })

    for idx, func in enumerate(functions):
        # New format: use composite_text for embedding
        embed_text = func.get("composite_text", "")

        # Fallback: old format used summary_index
        if not embed_text:
            embed_text = func.get("summary_index", "")

        if not embed_text:
            continue

        # Build purpose from new or old format
        purpose = (
            func.get("purpose", "")
            or func.get("core_purpose", "")
        )

        # Calls/dependencies from new or old format
        calls = func.get("calls", func.get("dependencies", []))
        called_by = func.get("called_by", [])
        economic_concepts = func.get("economic_concepts", [])
        inputs = func.get("inputs", [])
        outputs = func.get("outputs", [])
        algorithm = func.get("algorithm", "")

        # Determine content_type based on unit kind
        kind = func.get("kind", "subroutine")
        if kind == "program_section":
            content_type = "fortran_section"
        else:
            content_type = "fortran_function"

        chunks.append({
            "text": embed_text,
            "metadata": {
                "paper_title": paper_title,
                "authors": authors,
                "content_type": content_type,
                "function_name": func.get("function_name", func.get("name", "")),
                "kind": kind,
                "purpose": purpose,
                "calls": str(calls) if calls else "",
                "called_by": str(called_by) if called_by else "",
                "economic_concepts": str(economic_concepts) if economic_concepts else "",
                "algorithm": str(algorithm) if algorithm else "",
                "inputs": str(inputs) if inputs else "",
                "outputs": str(outputs) if outputs else "",
                "start_line": func.get("start_line", -1),
                "end_line": func.get("end_line", -1),
                "source_file": str(json_path),
                "sequence_idx": idx,
            },
        })

    logger.info("Processed Fortran digest: %d documents (incl. architecture)", len(chunks))
    return chunks


# ── paper registry ───────────────────────────────────────────────────────

def _update_paper_registry(
    registry_path: Union[str, Path],
    paper_title: str,
    authors: str,
    content_list_path: str,
    fortran_digest_path: str,
) -> None:
    """Append a paper entry to the registry JSON (or create it)."""
    registry_path = Path(registry_path)
    if registry_path.exists():
        with open(registry_path, "r", encoding="utf-8") as f:
            registry = json.load(f)
    else:
        registry = []

    # Upsert by title so canonical paths are always refreshed.
    updated = False
    for entry in registry:
        if entry.get("paper_title") == paper_title:
            entry["authors"] = authors
            entry["ingest_date"] = datetime.now(timezone.utc).isoformat()
            entry["content_list_path"] = content_list_path
            entry["fortran_digest_path"] = fortran_digest_path
            updated = True
            break

    if not updated:
        registry.append({
            "paper_title": paper_title,
            "authors": authors,
            "ingest_date": datetime.now(timezone.utc).isoformat(),
            "content_list_path": content_list_path,
            "fortran_digest_path": fortran_digest_path,
        })

    with open(registry_path, "w", encoding="utf-8") as f:
        json.dump(registry, f, indent=4, ensure_ascii=False)

    logger.info("Updated paper registry (%d papers)", len(registry))


# ── main orchestrator ─────────────────────────────────────────────────────

def store_ingested_data(
    ingest_result: Dict[str, str],
    db_path: Union[str, Path],
    collection_name: str = "rag_embeddings",
    embedding_model: str = _DEFAULT_MODEL,
    embedding_device: Optional[str] = None,
) -> Dict[str, int]:
    """
    Chunk, embed, and store ingested paper + Fortran code into Qdrant.

    Parameters
    ----------
    ingest_result : dict
        The dict returned by ``ingest_paper_and_code`` with keys:
        ``md_path``, ``content_list_json``, ``metadata_json``,
        ``fortran_digest_json``.
    db_path : path
        Directory for Qdrant persistent storage.
    collection_name : str
        Qdrant collection name.
    embedding_model / embedding_device : str
        Model name and device for sentence-transformers.

    Returns
    -------
    dict – counts: ``{"manuscript_chunks", "fortran_chunks", "total_in_db"}``
    """
    db_path = Path(db_path)
    db_path.mkdir(parents=True, exist_ok=True)

    content_list_json = ingest_result["content_list_json"]
    fortran_digest_json = ingest_result["fortran_digest_json"]

    # ── 1. Chunking ──────────────────────────────────────────────────────
    logger.info("═══ Step 1/3: Chunking ═══")
    ms_chunks = chunk_content_list(content_list_json)
    ft_chunks = chunk_fortran_digest(fortran_digest_json)
    all_chunks = ms_chunks + ft_chunks

    if not all_chunks:
        logger.warning("No chunks produced — nothing to store.")
        return {"manuscript_chunks": 0, "fortran_chunks": 0, "total_in_db": 0}

    logger.info("Total: %d manuscript + %d Fortran = %d chunks",
                len(ms_chunks), len(ft_chunks), len(all_chunks))

    # ── 2. Embedding ─────────────────────────────────────────────────────
    logger.info("═══ Step 2/3: Embedding ═══")
    embedder = EmbeddingModel(model_name=embedding_model, device=embedding_device)

    texts = [c["text"] for c in all_chunks]
    t0 = time.time()
    embeddings = embedder.embed_documents(texts)
    elapsed = time.time() - t0
    logger.info("Embedded %d chunks in %.1fs (%.1f chunks/s)",
                len(texts), elapsed, len(texts) / elapsed if elapsed else 0)

    # ── 3. Store in Qdrant ───────────────────────────────────────────────
    logger.info("═══ Step 3/3: Storing in Qdrant ═══")

    # Determine vector size from first embedding
    vector_size = len(embeddings[0]) if embeddings else 3584
    store = QdrantVectorStore(
        persist_dir=str(db_path / "qdrant_data"),
        collection_name=collection_name,
        vector_size=vector_size,
    )

    try:
        ids = []
        metadatas = []
        for c in all_chunks:
            meta = c["metadata"]
            doc_id = _make_id(
                meta["content_type"],
                meta.get("source_file", ""),
                meta.get("sequence_idx", meta.get("chunk_idx", 0)),
            )
            ids.append(doc_id)
            metadatas.append(meta)

        store.add_documents(
            texts=texts,
            embeddings=embeddings,
            metadatas=metadatas,
            ids=ids,
        )

        total = store.count
    finally:
        store.close()
    logger.info("✅  Stored %d documents (total in collection: %d)", len(all_chunks), total)

    # ── 4. Update paper registry ─────────────────────────────────────────
    # Read title/authors from the metadata JSON
    metadata_json = ingest_result.get("metadata_json", "")
    if metadata_json and Path(metadata_json).exists():
        with open(metadata_json, "r", encoding="utf-8") as f:
            meta = json.load(f)
        _update_paper_registry(
            registry_path=db_path / "paper_registry.json",
            paper_title=meta.get("paper_title", ""),
            authors=meta.get("authors", ""),
            content_list_path=content_list_json,
            fortran_digest_path=fortran_digest_json,
        )

    return {
        "manuscript_chunks": len(ms_chunks),
        "fortran_chunks": len(ft_chunks),
        "total_in_db": total,
    }


# ── CLI / manual test ─────────────────────────────────────────────────────

if __name__ == "__main__":
    repo_root = PROJECT_ROOT
    # Use existing ingest results from the previous test
    ingest_result = {
        "md_path": str(repo_root / "tests" / "ingest_results" / "Manuscript" / "auto" / "Manuscript.md"),
        "content_list_json": str(repo_root / "tests" / "ingest_results" / "Manuscript" / "auto" / "Manuscript_content_list.json"),
        "metadata_json": str(repo_root / "tests" / "ingest_results" / "metadata.json"),
        "fortran_digest_json": str(repo_root / "tests" / "ingest_results" / "benchmark_digest.json"),
    }
    db_path = repo_root / "db"

    result = store_ingested_data(
        ingest_result=ingest_result,
        db_path=db_path,
    )
    print("\n── Result ──")
    for k, v in result.items():
        print(f"  {k}: {v}")
