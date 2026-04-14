"""
Orchestrator: ingest a PDF paper and its companion Fortran code.

Pipeline
--------
1. Extract PDF via MinerU  → .md + _content_list.json
2. Parse paper title & authors from the first 600 words of the .md (LLM)
3. Describe images, equations, and tables for RAG indexing
4. Digest & summarise the Fortran code
5. Inject paper metadata into all output JSONs
"""
from __future__ import annotations

import json
import logging
import os
import re
import shutil
import sys
import uuid
from pathlib import Path
from typing import Dict, Optional, Union

from dotenv import load_dotenv

load_dotenv()

# ── path setup ────────────────────────────────────────────────────────────
CURRENT_DIR = Path(__file__).resolve().parent
PROJECT_ROOT = CURRENT_DIR.parent.parent

if str(PROJECT_ROOT) not in sys.path:
    sys.path.insert(0, str(PROJECT_ROOT))

from utils.s1_data_ingestion.pdf_extract import (
    extract_pdf_mineru,
    describe_mineru_images,
    describe_mineru_equations,
    describe_mineru_tables,
    _parse_subdir,
)
from utils.s1_data_ingestion.fortran_code_digest import (
    digest_fortran_code,
    summarize_fortran_digest,
)
from utils.llm_clients.local_llm import LocalLLMClient

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

# ── helpers ───────────────────────────────────────────────────────────────

def _first_n_words(text: str, n: int = 600) -> str:
    """Return the first *n* whitespace-delimited words of *text*."""
    words = text.split()
    return " ".join(words[:n])


def extract_paper_metadata(
    md_path: Union[str, Path],
    model_name: Optional[str] = None,
    base_url: Optional[str] = None,
    api_key: Optional[str] = None,
) -> Dict[str, str]:
    """
    Read the first 600 words of a MinerU-generated markdown file and use an
    LLM to extract the paper's title and authors.

    Returns
    -------
    dict  –  ``{"paper_title": "...", "authors": "..."}``
    """
    md_path = Path(md_path)
    if not md_path.exists():
        raise FileNotFoundError(f"Markdown file not found: {md_path}")

    with open(md_path, "r", encoding="utf-8") as f:
        full_text = f.read()

    snippet = _first_n_words(full_text, 600)

    model_name = model_name or os.getenv("LLM_MODEL_NAME", "gemma4:31b")
    base_url = base_url or os.getenv("LOCAL_LLM_BASE_URL", "http://localhost:11434/v1")
    api_key = api_key or os.getenv("LOCAL_LLM_API_KEY", "ollama")

    client = LocalLLMClient(
        model_name=model_name,
        base_url=base_url,
        api_key=api_key,
    )

    system_prompt = (
        "You are a metadata extraction system for academic papers. "
        "Given the beginning of a paper, extract the paper title and the "
        "author names. Return ONLY a JSON object with two keys: "
        '"paper_title" (string) and "authors" (string, comma-separated names). '
        "Do not include any other text."
    )

    user_prompt = (
        "Extract the paper title and authors from the following text. "
        "Return a JSON object with keys 'paper_title' and 'authors'.\n\n"
        f"---\n{snippet}\n---"
    )

    logger.info("Sending first 600 words to LLM for metadata extraction …")
    response = client.generate_response(
        user_prompt=user_prompt,
        system_prompt=system_prompt,
        response_mime_type="application/json",
        max_tokens=512,
        temperature=0.0,
    )

    # response is already a dict when response_mime_type is application/json
    if isinstance(response, dict):
        metadata = response
    else:
        metadata = json.loads(response)

    # Normalise keys
    metadata.setdefault("paper_title", "")
    metadata.setdefault("authors", "")
    logger.info("Extracted metadata – title: %s", metadata["paper_title"])
    return metadata


def _inject_metadata_into_json(
    json_path: Union[str, Path],
    metadata: Dict[str, str],
) -> None:
    """Add ``paper_title`` and ``authors`` as top-level keys in a JSON file."""
    json_path = Path(json_path)
    with open(json_path, "r", encoding="utf-8") as f:
        data = json.load(f)

    if isinstance(data, list):
        # Wrap list-style content_list into an object so we can attach metadata
        data = {"paper_title": metadata.get("paper_title", ""),
                "authors": metadata.get("authors", ""),
                "items": data}
    else:
        data["paper_title"] = metadata.get("paper_title", "")
        data["authors"] = metadata.get("authors", "")

    with open(json_path, "w", encoding="utf-8") as f:
        json.dump(data, f, indent=4, ensure_ascii=False)

    logger.info("Injected metadata into %s", json_path)


def _safe_title_dirname(title: str) -> str:
    """Create a filesystem-safe directory name from a paper title."""
    cleaned = re.sub(r"[^A-Za-z0-9._ -]+", "", title).strip()
    cleaned = re.sub(r"\s+", " ", cleaned)
    if not cleaned:
        cleaned = "untitled-paper"
    return cleaned[:180]


def _unique_dir(base_dir: Path) -> Path:
    """Return a non-conflicting directory path by appending a numeric suffix."""
    if not base_dir.exists():
        return base_dir
    idx = 2
    while True:
        candidate = base_dir.parent / f"{base_dir.name}-{idx}"
        if not candidate.exists():
            return candidate
        idx += 1


# ── main orchestrator ─────────────────────────────────────────────────────

def ingest_paper_and_code(
    pdf_path: Union[str, Path],
    fortran_path: Union[str, Path],
    output_dir: Union[str, Path],
    db_path: Optional[Union[str, Path]] = None,
    *,
    # MinerU options
    backend: str = "pipeline",
    method: str = "auto",
    lang: str = "en",
    # LLM options (defaults read from .env / environment)
    model_name: Optional[str] = None,
    base_url: Optional[str] = None,
    api_key: Optional[str] = None,
) -> Dict[str, str]:
    """
    End-to-end ingestion of a PDF paper and its companion Fortran code.

    Parameters
    ----------
    pdf_path : path
        Path to the input PDF file.
    fortran_path : path
        Path to the Fortran source file.
    output_dir : path
        Root directory where all processed outputs will be stored.
    db_path : path, optional
        Path to a database file (stored in metadata for downstream use).
    backend / method / lang : str
        Forwarded to ``extract_pdf_mineru``.
    model_name / base_url / api_key : str
        Connection parameters for the local LLM.

    Returns
    -------
    dict  – Paths to the produced artefacts::

        {
            "md_path":              "...",
            "content_list_json":    "...",
            "metadata_json":        "...",
            "fortran_digest_json":  "...",
        }
    """
    pdf_path = Path(pdf_path)
    fortran_path = Path(fortran_path)
    output_dir = Path(output_dir)
    output_dir.mkdir(parents=True, exist_ok=True)

    # Resolve LLM config from env if not provided
    model_name = model_name or os.getenv("LLM_MODEL_NAME", "gemma4:31b")
    base_url = base_url or os.getenv("LOCAL_LLM_BASE_URL", "http://localhost:11434/v1")
    api_key = api_key or os.getenv("LOCAL_LLM_API_KEY", "ollama")

    # ── staged ingest paths ───────────────────────────────────────────────
    stage_root = output_dir / "_tmp_ingest" / uuid.uuid4().hex
    stage_source_dir = stage_root / "source"
    stage_extract_dir = stage_root / "extract"
    stage_source_dir.mkdir(parents=True, exist_ok=True)
    stage_extract_dir.mkdir(parents=True, exist_ok=True)

    staged_pdf = stage_source_dir / pdf_path.name
    staged_fortran = stage_source_dir / fortran_path.name
    shutil.copy2(pdf_path, staged_pdf)
    shutil.copy2(fortran_path, staged_fortran)

    try:
        # ── 1. PDF extraction ────────────────────────────────────────────
        logger.info("═══ Step 1/5: Extracting PDF via MinerU ═══")
        subdir = _parse_subdir(backend, method)
        md_path = extract_pdf_mineru(
            input_path=staged_pdf,
            output_dir=stage_extract_dir,
            backend=backend,
            method=method,
            lang=lang,
        )
        json_path = stage_extract_dir / staged_pdf.stem / subdir / f"{staged_pdf.stem}_content_list.json"


        # ── 2. Metadata extraction (title + authors) ─────────────────────
        logger.info("═══ Step 2/5: Extracting paper metadata via LLM ═══")
        metadata = extract_paper_metadata(
            md_path=md_path,
            model_name=model_name,
            base_url=base_url,
            api_key=api_key,
        )

        title_dirname = _safe_title_dirname(metadata.get("paper_title", ""))
        paper_dir = _unique_dir(output_dir / title_dirname)
        paper_source_dir = paper_dir / "source"
        paper_extract_dir = paper_dir / "ingest_output"
        paper_source_dir.mkdir(parents=True, exist_ok=True)
        paper_extract_dir.mkdir(parents=True, exist_ok=True)

        final_pdf_path = paper_source_dir / staged_pdf.name
        final_fortran_path = paper_source_dir / staged_fortran.name
        shutil.move(str(staged_pdf), str(final_pdf_path))
        shutil.move(str(staged_fortran), str(final_fortran_path))

        extracted_pdf_dir = stage_extract_dir / staged_pdf.stem
        final_extracted_pdf_dir = paper_extract_dir / staged_pdf.stem
        shutil.move(str(extracted_pdf_dir), str(final_extracted_pdf_dir))

        md_path = final_extracted_pdf_dir / subdir / f"{staged_pdf.stem}.md"
        json_path = final_extracted_pdf_dir / subdir / f"{staged_pdf.stem}_content_list.json"

        # load json and clearn reference 
        
        if db_path is not None:
            metadata["db_path"] = str(db_path)
        metadata["paper_dir"] = str(paper_dir)
        metadata["source_pdf_path"] = str(final_pdf_path)
        metadata["source_fortran_path"] = str(final_fortran_path)
        metadata["ingest_output_dir"] = str(paper_extract_dir)
        metadata["md_path"] = str(md_path)
        metadata["content_list_path"] = str(json_path)

        metadata_json_path = paper_dir / "metadata.json"
        with open(metadata_json_path, "w", encoding="utf-8") as f:
            json.dump(metadata, f, indent=4, ensure_ascii=False)
        logger.info("Saved metadata to %s", metadata_json_path)

        # ── 2b. Trim content after "References" ────────────────────────
        logger.info("Trimming content list after References section …")
        with open(json_path, "r", encoding="utf-8") as f:
            cl_raw = json.load(f)

        if isinstance(cl_raw, dict) and "items" in cl_raw:
            cl_items = cl_raw["items"]
        else:
            cl_items = cl_raw

        ref_idx = None
        for i, item in enumerate(cl_items):
            if item.get("type") == "text" and re.match(
                r"^\s*references\s*$", item.get("text", ""), re.IGNORECASE
            ):
                ref_idx = i
                break

        if ref_idx is not None:
            removed = len(cl_items) - ref_idx
            cl_items = cl_items[:ref_idx]
            logger.info("Removed %d items after 'References' (index %d)", removed, ref_idx)
            if isinstance(cl_raw, dict) and "items" in cl_raw:
                cl_raw["items"] = cl_items
            else:
                cl_raw = cl_items
            with open(json_path, "w", encoding="utf-8") as f:
                json.dump(cl_raw, f, indent=4, ensure_ascii=False)
        else:
            logger.info("No 'References' heading found; keeping full content list.")

        # ── 3. Enrich images / equations / tables ────────────────────────
        logger.info("═══ Step 3/5: Describing images, equations & tables ═══")
        describe_mineru_images(json_path)
        describe_mineru_equations(json_path)
        describe_mineru_tables(json_path)

        # ── 4. Fortran code digestion ────────────────────────────────────
        logger.info("═══ Step 4/5: Digesting Fortran code ═══")
        fortran_digest_path = paper_dir / f"{final_fortran_path.stem}_digest.json"
        code_content = final_fortran_path.read_text(encoding="utf-8", errors="replace")
        digest_fortran_code(
            code_content=code_content,
            output_json_path=str(fortran_digest_path),
            model_name=model_name,
            base_url=base_url,
            api_key=api_key,
        )
        summarize_fortran_digest(
            json_path=fortran_digest_path,
            model_name=model_name,
            base_url=base_url,
            api_key=api_key,
        )

        metadata["fortran_digest_path"] = str(fortran_digest_path)
        with open(metadata_json_path, "w", encoding="utf-8") as f:
            json.dump(metadata, f, indent=4, ensure_ascii=False)

        # ── 5. Inject metadata into output JSONs ─────────────────────────
        logger.info("═══ Step 5/5: Injecting metadata into output JSONs ═══")
        _inject_metadata_into_json(json_path, metadata)
        _inject_metadata_into_json(fortran_digest_path, metadata)

        summary = {
            "paper_dir": str(paper_dir),
            "md_path": str(md_path),
            "content_list_json": str(json_path),
            "metadata_json": str(metadata_json_path),
            "fortran_digest_json": str(fortran_digest_path),
            "source_pdf_path": str(final_pdf_path),
            "source_fortran_path": str(final_fortran_path),
        }
    finally:
        shutil.rmtree(stage_root, ignore_errors=True)

    logger.info("✅  Ingestion complete. Artefacts:\n%s", json.dumps(summary, indent=2))
    return summary


# ── CLI / manual test ─────────────────────────────────────────────────────

if __name__ == "__main__":
    # Quick smoke-test using existing test fixtures
    repo_root = PROJECT_ROOT
    test_pdf = repo_root / "tests" / "Manuscript.pdf"
    test_fortran = repo_root / "tests" / "benchmark.f90"
    test_output = repo_root / "tests" / "output_orchestrator"

    result = ingest_paper_and_code(
        pdf_path=test_pdf,
        fortran_path=test_fortran,
        output_dir=test_output,
    )
    print("\n── Result ──")
    for k, v in result.items():
        print(f"  {k}: {v}")
