"""
Query router: decide whether a user query is *local* (about specifics inside
one or a few known papers) or *global* (comparative / aggregate across the
corpus), and extract focus concepts that help steer retrieval.

Global queries trigger a profile-first retrieval path: the profile index
selects candidate papers, then filtered chunk retrieval drills into each.
Local queries use the existing chunk-first pipeline.

Heuristic pre-filter runs first so obviously comparative phrasing does not
depend on the LLM; the LLM is consulted when the heuristic is uncertain.
"""
from __future__ import annotations

import logging
import re
from typing import Dict, List, Optional

from utils.llm_clients.local_llm import LocalLLMClient

logger = logging.getLogger(__name__)


_GLOBAL_PATTERNS = [
    # Direct paper-set references
    r"\bwhich\s+\w*\s*papers?\b",          # "which paper(s)", "which two papers"
    r"\bwhat\s+\w*\s*papers?\b",           # "what paper(s)", "what three papers"
    r"\bany\s+\w*\s*papers?\b",            # "any papers"
    r"\bmultiple\s+papers?\b",
    r"\bboth\s+papers?\b",
    r"\btwo\s+papers?\b",
    r"\bseveral\s+papers?\b",
    r"\bthese\s+papers?\b",
    r"\bacross\s+papers?\b",
    r"\bamong\s+\w*\s*papers?\b",
    # Comparison / commonality phrasing
    r"\bcompare\b",
    r"\bcomparison\b",
    r"\bcontrast\b",
    r"\bdiffer(ence|ences|s)?\b",
    r"\bsimilar(ly|ities|ity)?\b",
    r"\bsame\s+(model|method|framework|approach|technique)\b",
    r"\bshared?\s+(model|method|framework|approach|technique)\b",
    r"\bshare\s+(the\s+same|a\s+similar|similar)\b",
    r"\bin\s+common\b",
    r"\boverlap\b",
    r"\brelated\s+work\b",
    r"\bhow\s+do\s+.*\s+differ\b",
    r"\bhow\s+are\s+.*\s+(similar|related|connected)\b",
]

_GLOBAL_REGEX = re.compile("|".join(_GLOBAL_PATTERNS), re.IGNORECASE)


def _heuristic_scope(query: str) -> Optional[str]:
    """Return 'global' if the query clearly asks for cross-document synthesis."""
    if _GLOBAL_REGEX.search(query):
        return "global"
    return None


_SYSTEM_PROMPT = (
    "You route queries for an academic economics RAG system. "
    "Return ONLY valid JSON."
)


def _llm_classify(query: str, llm: LocalLLMClient) -> Dict:
    prompt = (
        "Classify the following question about a corpus of economics papers.\n\n"
        f"Question: \"{query}\"\n\n"
        "Return a JSON object with keys:\n"
        "- \"scope\": either \"local\" (a question about details inside one or a few "
        "specific papers / a specific concept) or \"global\" (a comparative, "
        "aggregate, or survey-style question that requires synthesising across "
        "multiple papers to answer, e.g. 'which papers use X', 'how do these "
        "papers differ in Y', 'what models are shared').\n"
        "- \"focus_concepts\": list of 2-5 short concept phrases the question is "
        "really about (e.g. [\"overlapping-generations model\", \"wealth "
        "inequality\"]). Use canonical terms if possible.\n"
        "Return ONLY the JSON object."
    )
    try:
        result = llm.generate_response(
            user_prompt=prompt,
            system_prompt=_SYSTEM_PROMPT,
            response_mime_type="application/json",
            max_tokens=256,
            temperature=0.0,
        )
        if not isinstance(result, dict):
            return {}
        return result
    except Exception as exc:
        logger.warning("Query classification via LLM failed: %s", exc)
        return {}


def classify_query(query: str, llm: LocalLLMClient) -> Dict:
    """
    Classify query into {"scope": "local"|"global", "focus_concepts": [...]}.

    Heuristic regex catches obvious comparative phrasing without an LLM call;
    otherwise the LLM decides.
    """
    heuristic = _heuristic_scope(query)
    llm_result = _llm_classify(query, llm)

    scope = heuristic or llm_result.get("scope") or "local"
    if scope not in ("local", "global"):
        scope = "local"

    focus_concepts = llm_result.get("focus_concepts") or []
    if not isinstance(focus_concepts, list):
        focus_concepts = []
    focus_concepts = [str(c).strip() for c in focus_concepts if str(c).strip()][:5]

    return {
        "scope": scope,
        "focus_concepts": focus_concepts,
    }
