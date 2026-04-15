"""
Generate natural-language summaries for each detected community.

A community summary is the unit of work for the global query path: the
LLM is later asked to judge, for each summary, what it contributes to
the user's question ("map" step), then partial contributions are merged
into a final answer ("reduce" step).

Output per community:

    {
      "community_id": int,
      "title": str,          # short label
      "summary": str,        # 2-4 sentence overview
      "theme": str,          # one-phrase theme (e.g. "life-cycle models")
      "key_entities": [name, ...],
      "paper_titles": [str, ...],
      "size": int
    }
"""
from __future__ import annotations

import json
import logging
from typing import Any, Dict, List, Optional

from utils.llm_clients.local_llm import LocalLLMClient

logger = logging.getLogger(__name__)


_SYSTEM_PROMPT = (
    "You summarise subgraphs of an academic economics knowledge graph. "
    "Each community is a cluster of entities (economic models, concepts, "
    "methods, datasets, etc.) and the relationships that connect them. "
    "Produce a faithful, concrete summary that reflects the ENTITIES and "
    "RELATIONSHIPS given — do not invent details. Return ONLY valid JSON."
)


def _render_evidence(evidence: Dict[str, Any], max_entities: int = 40) -> str:
    lines: List[str] = []
    lines.append(f"Community size: {evidence.get('size', 0)} entities")
    papers = evidence.get("paper_titles", [])
    if papers:
        lines.append(f"Source papers: {', '.join(papers[:8])}")
    lines.append("")
    lines.append("Entities:")
    for e in evidence.get("entities", [])[:max_entities]:
        desc = ""
        if e.get("descriptions"):
            desc = " — " + (e["descriptions"][0] if e["descriptions"] else "")
        lines.append(f"  - [{e.get('type', '?')}] {e.get('name', '')}{desc}")
    rels = evidence.get("relationships", [])
    if rels:
        lines.append("")
        lines.append("Relationships:")
        for r in rels:
            desc = f" ({r['description']})" if r.get("description") else ""
            lines.append(
                f"  - {r['source']} --[{r['type']}, w={r['weight']}]--> "
                f"{r['target']}{desc}"
            )
    return "\n".join(lines)


class CommunitySummarizer:
    def __init__(self, llm_client: Optional[LocalLLMClient] = None) -> None:
        self.llm = llm_client or LocalLLMClient()

    def summarize(
        self,
        community_id: int,
        evidence: Dict[str, Any],
    ) -> Dict[str, Any]:
        prompt = (
            "Given the following subgraph of economics entities and "
            "relationships, produce a JSON object with keys:\n"
            "- \"title\": 3-8 word human-readable label for this cluster\n"
            "- \"theme\": one canonical phrase capturing the theme (e.g. "
            "\"overlapping-generations models\", \"monetary policy\")\n"
            "- \"summary\": 2-4 sentences describing what this cluster is "
            "about and how the entities connect\n"
            "- \"key_entities\": up to 8 most-central entity names from the list\n\n"
            "Return ONLY the JSON object.\n\n"
            f"Subgraph:\n---\n{_render_evidence(evidence)}\n---"
        )
        try:
            raw = self.llm.generate_response(
                user_prompt=prompt,
                system_prompt=_SYSTEM_PROMPT,
                response_mime_type="application/json",
                max_tokens=800,
                temperature=0.2,
            )
        except Exception as exc:
            logger.warning("Community %s summarisation failed: %s", community_id, exc)
            raw = {}

        if not isinstance(raw, dict):
            try:
                raw = json.loads(raw) if isinstance(raw, str) else {}
            except Exception:
                raw = {}

        key_entities = raw.get("key_entities") or []
        if not isinstance(key_entities, list):
            key_entities = []
        key_entities = [str(x).strip() for x in key_entities if str(x).strip()][:8]

        return {
            "community_id": int(community_id),
            "title": str(raw.get("title", "")).strip() or f"Community {community_id}",
            "theme": str(raw.get("theme", "")).strip(),
            "summary": str(raw.get("summary", "")).strip(),
            "key_entities": key_entities,
            "paper_titles": list(evidence.get("paper_titles", [])),
            "size": int(evidence.get("size", 0)),
        }

    def summarize_all(
        self,
        communities_evidence: Dict[int, Dict[str, Any]],
    ) -> List[Dict[str, Any]]:
        out: List[Dict[str, Any]] = []
        for cid, evidence in communities_evidence.items():
            logger.info("Summarising community %s (size=%s)…", cid, evidence.get("size"))
            out.append(self.summarize(cid, evidence))
        return out
