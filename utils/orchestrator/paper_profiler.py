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


def _as_str(value: Any) -> str:
    """
    Coerce any JSON-compatible value to a trimmed string.

    Ingest-output JSONs occasionally hold list-valued fields where we
    expect a string (e.g. multi-line captions, description arrays).
    Without this helper, downstream ``.strip()`` calls crash the whole
    profile build.
    """
    if value is None:
        return ""
    if isinstance(value, str):
        return value.strip()
    if isinstance(value, list):
        return " ".join(_as_str(v) for v in value if v is not None).strip()
    if isinstance(value, dict):
        return " ".join(_as_str(v) for v in value.values() if v is not None).strip()
    return str(value).strip()


def _extract_manuscript_text(content_list_json: Union[str, Path], max_chars: int) -> str:
    """Flatten the content-list JSON to a text blob preserving section structure."""
    items = _load_content_list(content_list_json)
    parts: List[str] = []
    for item in items:
        if not isinstance(item, dict):
            continue
        t = _as_str(item.get("type"))
        if t == "text":
            text = _as_str(item.get("text"))
            if not text:
                continue
            if "text_level" in item:
                parts.append(f"\n## {text}\n")
            else:
                parts.append(text)
        elif t == "equation":
            latex = _as_str(item.get("text"))
            desc = _as_str(item.get("description"))
            if latex or desc:
                parts.append(f"[Equation] {latex}\n{desc}".strip())
        elif t == "table":
            cap = _as_str(item.get("table_caption"))
            desc = _as_str(item.get("description"))
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
    arch = _as_str(data.get("architecture_overview"))
    funcs = data.get("key_functions", []) or []
    fn_names: List[str] = []
    for f in funcs:
        if not isinstance(f, dict):
            continue
        name = _as_str(f.get("function_name")) or _as_str(f.get("name"))
        if name:
            fn_names.append(name)
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
        "research_question": _as_str(profile.get("research_question")),
        "summary": _as_str(profile.get("summary")),
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


# ── Overlap analysis (deterministic cross-paper comparison) ─────────────

# Canonicalisation table: collapse common synonym clusters so "OLG",
# "overlapping-generations", and "life-cycle model" all hash to the same
# family. Keys are the normalised output; each set holds the substrings
# that trigger the mapping. Matching is lowercase-substring, so partial
# fits work (e.g. "overlapping-generations heterogeneous-agent" → "olg").
_MODEL_CANON = {
    "olg / life-cycle": {
        "olg", "overlapping-generations", "overlapping generations",
        "life-cycle", "life cycle",
    },
    "heterogeneous-agent (Bewley/Aiyagari/Huggett)": {
        "heterogeneous-agent", "heterogeneous agent",
        "bewley", "aiyagari", "huggett", "incomplete markets",
    },
    "dynastic (Barro-Becker)": {
        "dynastic", "barro-becker", "altruistic",
    },
    "DSGE": {"dsge", "dynamic stochastic general equilibrium"},
    "Krusell-Smith": {"krusell-smith", "krusell smith"},
}

_METHOD_CANON = {
    "value function iteration": {"value function iteration", "vfi"},
    "endogenous grid method": {"endogenous grid", "egm"},
    "policy function iteration": {"policy function iteration", "pfi"},
    "simulated method of moments": {"simulated method of moments", "smm"},
    "Krusell-Smith algorithm": {"krusell-smith algorithm", "krusell smith algorithm"},
    "transition path": {"transition path"},
}


def _canonicalise(value: str, table: Dict[str, set]) -> str:
    v = value.strip().lower()
    if not v:
        return v
    for canonical, triggers in table.items():
        for t in triggers:
            if t in v:
                return canonical
    return v


def _canonical_set(values: Any, table: Dict[str, set]) -> set:
    """Map a profile list field to a set of canonical family names."""
    out: set = set()
    if not values:
        return out
    if isinstance(values, str):
        values = [values]
    for v in values:
        c = _canonicalise(str(v), table)
        if c:
            out.add(c)
    return out


def compute_profile_overlap(profiles: List[Dict[str, Any]]) -> str:
    """
    Return a structured text block describing pairwise overlaps between
    profile records — canonicalised model/method/concept sets.

    ``profiles`` may be raw profile dicts or retrieval records with
    ``metadata`` payloads; both are accepted.
    """
    from itertools import combinations

    papers: List[Dict[str, Any]] = []
    for p in profiles:
        meta = p.get("metadata") if isinstance(p.get("metadata"), dict) else p
        title = meta.get("paper_title", "") or p.get("paper_title", "")
        if not title:
            continue
        papers.append({
            "title": title,
            "models": _canonical_set(meta.get("mathematical_models"), _MODEL_CANON),
            "methods": _canonical_set(meta.get("computational_methods"), _METHOD_CANON),
            "concepts": {
                str(c).strip().lower()
                for c in (meta.get("economic_concepts") or [])
                if str(c).strip()
            },
            # Raw (non-canonical) sets so we can still surface exact matches
            # when the canonicaliser produced no fit.
            "raw_models": {
                str(m).strip().lower()
                for m in (meta.get("mathematical_models") or [])
                if str(m).strip()
            },
            "raw_methods": {
                str(m).strip().lower()
                for m in (meta.get("computational_methods") or [])
                if str(m).strip()
            },
        })

    if len(papers) < 2:
        return ""

    lines: List[str] = []
    lines.append("# CROSS-PAPER OVERLAP ANALYSIS (pre-computed from structured profile fields)")
    any_overlap = False
    for a, b in combinations(papers, 2):
        segments: List[str] = []
        model_overlap = a["models"] & b["models"]
        if model_overlap:
            segments.append(
                "shared model families: " + ", ".join(sorted(model_overlap))
            )
        raw_model_overlap = a["raw_models"] & b["raw_models"]
        raw_model_overlap -= {m.lower() for m in model_overlap}
        if raw_model_overlap:
            segments.append(
                "shared model terms (verbatim): " + ", ".join(sorted(raw_model_overlap))
            )
        method_overlap = a["methods"] & b["methods"]
        if method_overlap:
            segments.append(
                "shared computational methods: " + ", ".join(sorted(method_overlap))
            )
        raw_method_overlap = a["raw_methods"] & b["raw_methods"]
        raw_method_overlap -= {m.lower() for m in method_overlap}
        if raw_method_overlap:
            segments.append(
                "shared method terms (verbatim): " + ", ".join(sorted(raw_method_overlap))
            )
        concept_overlap = a["concepts"] & b["concepts"]
        if concept_overlap:
            # Cap concept overlap at 6 to avoid flooding the prompt.
            segments.append(
                "shared economic concepts: " + ", ".join(sorted(concept_overlap)[:6])
            )

        if segments:
            any_overlap = True
            lines.append(f'- "{a["title"]}" ∩ "{b["title"]}":')
            for s in segments:
                lines.append(f"    - {s}")

    if not any_overlap:
        lines.append(
            "- No overlap detected between the structured profile fields of the "
            "candidate papers. The papers likely use distinct model families."
        )
    return "\n".join(lines)


def format_profile_block(profile: Dict[str, Any], ref_id: str = "") -> str:
    """Human-readable block for inclusion in the LLM context.

    ``ref_id`` is accepted for backwards compatibility but is no longer
    rendered — answers now reference papers by title, not by opaque tags.
    """
    del ref_id  # intentionally unused
    title = profile.get("paper_title", "") or "(untitled)"
    lines = [f'PAPER PROFILE — "{title}"']
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
