"""
Orchestrator: build a structured per-paper profile.

For global / cross-document questions ("which papers use similar mathematical
models?"), chunk-level retrieval cannot surface paper-level identity. This
module produces one structured JSON profile per paper capturing its models,
methods, concepts, and findings so a second Qdrant collection can serve as a
"paper identity" index the query router uses to pick candidate papers before
drilling into their chunks.
"""
from __future__ import annotations

import json
import logging
from pathlib import Path
from typing import Any, Dict, List, Optional, Union

from utils.llm_clients.local_llm import LocalLLMClient

logger = logging.getLogger(__name__)

PROFILE_COLLECTION = "paper_profiles"

PROFILE_FIELDS = (
    "research_question",
    "summary",
    "mathematical_models",
    "key_equations",
    "economic_concepts",
    "computational_methods",
    "data_sources",
    "main_findings",
    "keywords",
)

_SYSTEM_PROMPT = (
    "You analyze academic economics papers and extract structured profiles so "
    "a retrieval system can identify papers that share models, methods, or "
    "concepts. Return ONLY valid JSON. Use canonical terms "
    "(e.g., 'overlapping-generations model', 'heterogeneous-agent Bewley', "
    "'DSGE', 'value function iteration', 'endogenous grid method'). Extract "
    "only what is supported by the text — do not invent."
)


def _load_content_list(path: Union[str, Path]) -> List[Dict]:
    with open(path, "r", encoding="utf-8") as f:
        data = json.load(f)
    if isinstance(data, dict) and "items" in data:
        return data["items"]
    if isinstance(data, list):
        return data
    return []


def _extract_manuscript_text(content_list_json: Union[str, Path], max_chars: int) -> str:
    """Flatten the content-list JSON to a text blob preserving section structure."""
    items = _load_content_list(content_list_json)
    parts: List[str] = []
    for item in items:
        t = item.get("type", "")
        if t == "text":
            text = (item.get("text") or "").strip()
            if not text:
                continue
            if "text_level" in item:
                parts.append(f"\n## {text}\n")
            else:
                parts.append(text)
        elif t == "equation":
            latex = (item.get("text") or "").strip()
            desc = (item.get("description") or "").strip()
            if latex or desc:
                parts.append(f"[Equation] {latex}\n{desc}".strip())
        elif t == "table":
            cap = (item.get("table_caption") or "").strip()
            desc = (item.get("description") or "").strip()
            if cap or desc:
                parts.append(f"[Table: {cap}] {desc}".strip())
    blob = "\n".join(parts)
    if len(blob) > max_chars:
        # Keep head + tail so introduction and conclusions both survive.
        head = blob[: int(max_chars * 0.7)]
        tail = blob[-int(max_chars * 0.3) :]
        blob = head + "\n\n[...truncated...]\n\n" + tail
    return blob


def _extract_fortran_summary(fortran_digest_json: Union[str, Path]) -> str:
    path = Path(fortran_digest_json)
    if not path.exists():
        return ""
    with open(path, "r", encoding="utf-8") as f:
        data = json.load(f)
    arch = (data.get("architecture_overview") or "").strip()
    funcs = data.get("key_functions", []) or []
    fn_names = [
        (f.get("function_name") or f.get("name") or "").strip()
        for f in funcs
    ]
    fn_names = [n for n in fn_names if n]
    lines = []
    if arch:
        lines.append(f"Architecture: {arch}")
    if fn_names:
        lines.append(f"Key Fortran units: {', '.join(fn_names[:30])}")
    return "\n".join(lines)


def _normalise_list(value: Any) -> List[str]:
    if value is None:
        return []
    if isinstance(value, list):
        return [str(v).strip() for v in value if str(v).strip()]
    if isinstance(value, str):
        return [value.strip()] if value.strip() else []
    return [str(value).strip()]


def build_paper_profile(
    content_list_json: Union[str, Path],
    fortran_digest_json: Optional[Union[str, Path]],
    paper_title: str,
    authors: str,
    llm_client: LocalLLMClient,
    max_manuscript_chars: int = 80_000,
) -> Dict[str, Any]:
    """Extract a structured paper profile via the local LLM."""
    manuscript = _extract_manuscript_text(content_list_json, max_manuscript_chars)
    fortran_summary = _extract_fortran_summary(fortran_digest_json) if fortran_digest_json else ""

    user_prompt = (
        f"Paper: {paper_title}\n"
        f"Authors: {authors}\n\n"
        "Manuscript content:\n---\n"
        f"{manuscript}\n---\n\n"
        f"Fortran code summary:\n{fortran_summary or '(none)'}\n\n"
        "Extract a JSON object with exactly these keys (use [] if truly absent):\n"
        "- \"research_question\": one-sentence statement of what the paper asks\n"
        "- \"summary\": 3-5 sentence plain-language summary of the paper\n"
        "- \"mathematical_models\": list of model families (e.g., "
        "\"overlapping-generations\", \"heterogeneous-agent Bewley\", "
        "\"two-sector DSGE\"). Use canonical names.\n"
        "- \"key_equations\": list of distinctive equation names or forms "
        "(e.g., \"Euler equation\", \"Bellman equation\", \"HJB\")\n"
        "- \"economic_concepts\": list of central concepts (e.g., \"wealth "
        "inequality\", \"idiosyncratic income risk\", \"human capital\")\n"
        "- \"computational_methods\": list of numerical methods (e.g., "
        "\"value function iteration\", \"endogenous grid method\", "
        "\"Krusell-Smith algorithm\")\n"
        "- \"data_sources\": datasets or empirical sources (e.g., \"SCF\", "
        "\"PSID\"); [] if purely theoretical\n"
        "- \"main_findings\": 3-5 core findings or conclusions\n"
        "- \"keywords\": 5-10 keywords capturing the paper's identity\n\n"
        "Return ONLY the JSON object."
    )

    raw = llm_client.generate_response(
        user_prompt=user_prompt,
        system_prompt=_SYSTEM_PROMPT,
        response_mime_type="application/json",
        max_tokens=2048,
        temperature=0.1,
    )

    profile: Dict[str, Any] = raw if isinstance(raw, dict) else {}
    # Normalise — required fields always present with expected types.
    clean: Dict[str, Any] = {
        "paper_title": paper_title,
        "authors": authors,
        "research_question": str(profile.get("research_question", "") or "").strip(),
        "summary": str(profile.get("summary", "") or "").strip(),
        "mathematical_models": _normalise_list(profile.get("mathematical_models")),
        "key_equations": _normalise_list(profile.get("key_equations")),
        "economic_concepts": _normalise_list(profile.get("economic_concepts")),
        "computational_methods": _normalise_list(profile.get("computational_methods")),
        "data_sources": _normalise_list(profile.get("data_sources")),
        "main_findings": _normalise_list(profile.get("main_findings")),
        "keywords": _normalise_list(profile.get("keywords")),
    }
    return clean


def profile_to_embed_text(profile: Dict[str, Any]) -> str:
    """Composite text used for embedding and BM25 over profiles."""
    lines: List[str] = []
    lines.append(f"PAPER: {profile.get('paper_title', '')}")
    if authors := profile.get("authors"):
        lines.append(f"AUTHORS: {authors}")
    if rq := profile.get("research_question"):
        lines.append(f"RESEARCH QUESTION: {rq}")
    if s := profile.get("summary"):
        lines.append(f"SUMMARY: {s}")

    def _join(key: str, label: str) -> None:
        vals = profile.get(key) or []
        if vals:
            lines.append(f"{label}: {', '.join(str(v) for v in vals)}")

    _join("mathematical_models", "MATHEMATICAL MODELS")
    _join("key_equations", "KEY EQUATIONS")
    _join("economic_concepts", "ECONOMIC CONCEPTS")
    _join("computational_methods", "COMPUTATIONAL METHODS")
    _join("data_sources", "DATA SOURCES")
    _join("keywords", "KEYWORDS")

    findings = profile.get("main_findings") or []
    if findings:
        lines.append("MAIN FINDINGS:")
        for f in findings:
            lines.append(f"  - {f}")
    return "\n".join(lines)


def profile_to_payload(profile: Dict[str, Any]) -> Dict[str, Any]:
    """
    Qdrant payload — keep scalar fields as strings/lists so they can be used
    as filters later. Lists are serialised to JSON strings because Qdrant
    filter syntax on nested lists is awkward; we still keep the raw list
    under a separate key for readable display.
    """
    payload: Dict[str, Any] = {
        "content_type": "paper_profile",
        "paper_title": profile.get("paper_title", ""),
        "authors": profile.get("authors", ""),
        "research_question": profile.get("research_question", ""),
        "summary": profile.get("summary", ""),
    }
    for key in (
        "mathematical_models",
        "key_equations",
        "economic_concepts",
        "computational_methods",
        "data_sources",
        "main_findings",
        "keywords",
    ):
        vals = profile.get(key) or []
        payload[key] = list(vals)
    return payload


def format_profile_block(profile: Dict[str, Any], ref_id: str) -> str:
    """Human-readable block for inclusion in the LLM context."""
    lines = [f"[{ref_id}] PAPER PROFILE — {profile.get('paper_title', '')}"]
    if authors := profile.get("authors"):
        lines.append(f"  Authors: {authors}")
    if rq := profile.get("research_question"):
        lines.append(f"  Research question: {rq}")
    if s := profile.get("summary"):
        lines.append(f"  Summary: {s}")

    def _fmt(key: str, label: str) -> None:
        vals = profile.get(key) or []
        if vals:
            lines.append(f"  {label}: {', '.join(str(v) for v in vals)}")

    _fmt("mathematical_models", "Mathematical models")
    _fmt("key_equations", "Key equations")
    _fmt("economic_concepts", "Economic concepts")
    _fmt("computational_methods", "Computational methods")
    _fmt("data_sources", "Data sources")

    findings = profile.get("main_findings") or []
    if findings:
        lines.append("  Main findings:")
        for f in findings:
            lines.append(f"    - {f}")
    return "\n".join(lines)
