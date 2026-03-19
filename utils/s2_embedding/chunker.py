"""
Chunking strategies for academic manuscript text and Fortran code.

Manuscript: section-aware semantic chunking — filters type=="text" entries,
groups by page, merges consecutive paragraphs into chunks with token overlap.

Fortran: line-based chunking — reads each code file, splits into sub-chunks
with overlap, prepends the summary for retrieval context.
"""

import json
from pathlib import Path
from typing import Dict, List, Set


def _estimate_tokens(text: str) -> int:
    """Rough token estimate: ~0.75 tokens per whitespace-delimited word."""
    return int(len(text.split()) * 1.33)


def chunk_manuscript(
    json_path: str,
    max_tokens: int = 384,
    overlap_tokens: int = 64,
) -> list[dict]:
    """
    Chunk manuscript content_list.json into retrieval-ready pieces.

    Filters for type=="text" entries only, merges consecutive paragraphs
    into chunks up to `max_tokens` with `overlap_tokens` overlap.

    Returns list of dicts with keys:
        - text: the chunk text
        - metadata: dict with source_file, page_idx, chunk_idx, content_type
    """
    with open(json_path, "r", encoding="utf-8") as f:
        entries = json.load(f)

    # Filter text-only entries and keep relevant fields
    text_entries = [
        e for e in entries if e.get("type") == "text"
    ]

    if not text_entries:
        return []

    # Build chunks by merging consecutive paragraphs
    chunks = []
    current_texts: list[str] = []
    current_tokens = 0
    current_pages: set[int] = set()
    chunk_idx = 0

    def _flush():
        nonlocal chunk_idx, current_texts, current_tokens, current_pages
        if not current_texts:
            return
        merged = "\n\n".join(current_texts)
        chunks.append({
            "text": merged,
            "metadata": {
                "source_file": str(json_path),
                "page_indices": sorted(current_pages),
                "chunk_idx": chunk_idx,
                "content_type": "manuscript",
            },
        })
        chunk_idx += 1

        # Compute overlap: keep trailing text that fits within overlap_tokens
        overlap_texts = []
        overlap_tok = 0
        for t in reversed(current_texts):
            t_tok = _estimate_tokens(t)
            if overlap_tok + t_tok > overlap_tokens:
                break
            overlap_texts.insert(0, t)
            overlap_tok += t_tok

        current_texts = overlap_texts
        current_tokens = overlap_tok
        current_pages = set()

    for entry in text_entries:
        text = entry.get("text", "").strip()
        if not text:
            continue

        entry_tokens = _estimate_tokens(text)
        page_idx = entry.get("page_idx", -1)

        # If adding this entry would exceed max_tokens, flush first
        if current_tokens + entry_tokens > max_tokens and current_texts:
            _flush()

        current_texts.append(text)
        current_tokens += entry_tokens
        current_pages.add(page_idx)

    # Flush remaining
    _flush()

    return chunks


def chunk_fortran(
    json_path: str,
    lines_per_chunk: int = 150,
    overlap_lines: int = 30,
) -> list[dict]:
    """
    Chunk Fortran code files referenced in fortran_chunks.json.

    Each entry in the JSON maps a summary to a file path. We read each file,
    split into sub-chunks by line count with overlap, and prepend the summary.

    Returns list of dicts with keys:
        - text: summary + code sub-chunk
        - metadata: dict with source_file, file_name, summary, chunk_idx,
                     line_start, line_end, content_type
    """
    with open(json_path, "r", encoding="utf-8") as f:
        entries = json.load(f)

    chunks = []

    for summary, info in entries.items():
        file_path = info.get("path", "")
        file_name = info.get("name", "")

        if not file_path or not Path(file_path).exists():
            print(f"Warning: Fortran file not found: {file_path}")
            continue

        with open(file_path, "r", encoding="utf-8") as f:
            lines = f.readlines()

        total_lines = len(lines)
        chunk_idx = 0
        start = 0

        while start < total_lines:
            end = min(start + lines_per_chunk, total_lines)
            code_block = "".join(lines[start:end])

            # Prepend summary for retrieval context
            chunk_text = (
                f"[Summary]: {summary}\n"
                f"[File]: {file_name}\n"
                f"[Lines {start + 1}-{end}]\n\n"
                f"{code_block}"
            )

            chunks.append({
                "text": chunk_text,
                "metadata": {
                    "source_file": file_path,
                    "file_name": file_name,
                    "summary": summary,
                    "chunk_idx": chunk_idx,
                    "line_start": start + 1,
                    "line_end": end,
                    "content_type": "code",
                },
            })

            chunk_idx += 1
            start = end - overlap_lines if end < total_lines else total_lines

    return chunks
