"""
Global query path: map-reduce over community summaries.

Designed for comparative / aggregate questions that span the whole
corpus ("which papers use similar mathematical models?"). The chunk-level
RAG pipeline cannot reliably answer these because it only sees a thin
slice of evidence per paper. Here we operate over per-community
summaries — each is already a synthesised view of a coherent slice of
the corpus.

Pipeline
--------
1. **Pre-filter** community summaries by relevance to the query (cheap
   embedding similarity over summary text), keeping the top-K.
2. **Map**: for each surviving summary, ask the LLM what the community
   contributes to answering the query. Score each contribution.
3. **Reduce**: pass the ranked partial contributions to the LLM with the
   original question to write the final answer.
"""
from __future__ import annotations

import logging
from typing import Any, Dict, List, Optional

import numpy as np

from utils.llm_clients.local_llm import LocalLLMClient
from utils.s2_embedding.embedder import EmbeddingModel

logger = logging.getLogger(__name__)


_MAP_SYSTEM_PROMPT = (
    "You judge how a single knowledge-graph community contributes to a "
    "user's question. Return ONLY valid JSON."
)


_REDUCE_SYSTEM_PROMPT = (
    "You synthesise a final answer from independent partial contributions, "
    "each derived from a different community of an academic economics "
    "knowledge graph. Reflect every relevant contribution faithfully and "
    "make explicit comparisons where appropriate. Write in a natural, "
    "flowing prose style. Do NOT include citation tags such as [Cm-N] or "
    "any bracketed reference markers in your answer; attribute claims to "
    "papers or authors by name inline when needed.\n\n"
    "Math formatting: pick ONE representation per value. Either prose "
    "('gamma equals 2.0') OR LaTeX ('$\\gamma = 2.0$') — NEVER write the "
    "value twice in two notations back-to-back, and never put the LaTeX "
    "form on one line and the Unicode form on the next. Use $...$ for "
    "inline math and $$...$$ for display math; do not use \\(...\\) or "
    "\\[...\\]. For tables, keep each row on a single line and do not "
    "duplicate cell values."
)


def _community_text(summary: Dict[str, Any]) -> str:
    parts = [summary.get("title", ""), summary.get("theme", ""), summary.get("summary", "")]
    if summary.get("key_entities"):
        parts.append("Key entities: " + ", ".join(summary["key_entities"]))
    if summary.get("paper_titles"):
        parts.append("Papers: " + ", ".join(summary["paper_titles"][:8]))
    return "\n".join(p for p in parts if p)


def _rank_communities(
    query: str,
    summaries: List[Dict[str, Any]],
    embedder: EmbeddingModel,
    top_k: int,
) -> List[Dict[str, Any]]:
    if not summaries:
        return []
    q_vec = np.asarray(embedder.embed_query(query), dtype=np.float32)
    q_vec = q_vec / (np.linalg.norm(q_vec) + 1e-12)

    texts = [_community_text(s) for s in summaries]
    matrix = np.asarray(embedder.embed_documents(texts), dtype=np.float32)
    norms = np.linalg.norm(matrix, axis=1, keepdims=True) + 1e-12
    matrix = matrix / norms
    sims = matrix @ q_vec
    order = np.argsort(-sims)[:top_k]
    out = []
    for i in order:
        s = dict(summaries[int(i)])
        s["_relevance"] = float(sims[int(i)])
        out.append(s)
    return out


def _map_step(
    query: str,
    community: Dict[str, Any],
    llm: LocalLLMClient,
) -> Dict[str, Any]:
    prompt = (
        f"User question: \"{query}\"\n\n"
        "Community summary:\n"
        f"Title: {community.get('title', '')}\n"
        f"Theme: {community.get('theme', '')}\n"
        f"Summary: {community.get('summary', '')}\n"
        f"Key entities: {', '.join(community.get('key_entities') or [])}\n"
        f"Papers in this community: {', '.join(community.get('paper_titles') or [])}\n\n"
        "Return a JSON object:\n"
        "- \"contribution\": 1-4 sentences describing what THIS community "
        "contributes to answering the question. Be specific about which "
        "papers, models, or concepts apply. Empty string if irrelevant.\n"
        "- \"score\": integer 0-10 — how much the contribution helps "
        "answer the question (0 = unrelated)."
    )
    try:
        raw = llm.generate_response(
            user_prompt=prompt,
            system_prompt=_MAP_SYSTEM_PROMPT,
            response_mime_type="application/json",
            max_tokens=512,
            temperature=0.1,
        )
    except Exception as exc:
        logger.warning("Map step failed for community %s: %s", community.get("community_id"), exc)
        return {"contribution": "", "score": 0}
    if not isinstance(raw, dict):
        raw = {}
    try:
        score = int(raw.get("score", 0))
    except (TypeError, ValueError):
        score = 0
    score = max(0, min(10, score))
    return {
        "contribution": str(raw.get("contribution", "")).strip(),
        "score": score,
    }


def _format_contributions(items: List[Dict[str, Any]], max_items: int = 12) -> str:
    keep = [it for it in items if it.get("contribution") and it.get("score", 0) > 0]
    keep.sort(key=lambda x: -x["score"])
    keep = keep[:max_items]
    if not keep:
        return "(no relevant communities)"
    lines: List[str] = []
    for it in keep:
        cid = it.get("community_id", "?")
        tag = f"[Cm-{cid}]"
        title = it.get("title", "")
        contrib = it.get("contribution", "")
        papers = it.get("paper_titles") or []
        paper_str = (" Papers: " + ", ".join(papers[:6])) if papers else ""
        lines.append(f"{tag} {title} (score={it['score']})")
        lines.append(f"  {contrib}{paper_str}")
        lines.append("")
    return "\n".join(lines).strip()


class GlobalSearch:
    def __init__(
        self,
        community_summaries: List[Dict[str, Any]],
        embedder: EmbeddingModel,
        llm: LocalLLMClient,
    ) -> None:
        self.summaries = community_summaries
        self.embedder = embedder
        self.llm = llm

    def search(
        self,
        query: str,
        candidate_top_k: int = 12,
        keep_top_k: int = 8,
        max_generation_tokens: int = 30_000,
        conversation_history: Optional[List[Dict[str, str]]] = None,
    ) -> Dict[str, Any]:
        if not self.summaries:
            return {
                "answer": "No community summaries available — build the graph first.",
                "communities": [],
            }

        # Resolve follow-up references using prior turns BEFORE we rank
        # community summaries, so retrieval matches the user's true intent.
        from .local_search import _rewrite_query_with_history, format_conversation_history

        retrieval_query = _rewrite_query_with_history(query, conversation_history, self.llm)
        if retrieval_query != query:
            logger.info("Global rewrote follow-up: %r -> %r", query, retrieval_query)

        candidates = _rank_communities(retrieval_query, self.summaries, self.embedder, candidate_top_k)
        logger.info("Global search: %d candidate communities", len(candidates))

        contributions: List[Dict[str, Any]] = []
        for c in candidates:
            mapped = _map_step(retrieval_query, c, self.llm)
            contributions.append({
                **c,
                **mapped,
            })

        contributions.sort(key=lambda x: -x.get("score", 0))
        survivors = [c for c in contributions if c.get("score", 0) > 0][:keep_top_k]

        contributions_block = _format_contributions(survivors, max_items=keep_top_k)
        history_block = format_conversation_history(conversation_history)

        prompt_parts = [f"<question>\n{query}\n</question>"]
        if history_block:
            prompt_parts.append(
                f"<conversation_history>\n{history_block}\n</conversation_history>"
            )
        prompt_parts.append(
            "<community_contributions>\n"
            f"{contributions_block}\n"
            "</community_contributions>"
        )
        prompt_parts.append(
            "Write the final answer to the latest question using these "
            "contributions. The conversation_history (if present) is context "
            "for resolving follow-ups; do not repeat earlier answers. Make "
            "explicit cross-paper comparisons (similarities, differences, "
            "common models/methods). Answer naturally in prose and do NOT "
            "include citation tags like [Cm-N]; attribute claims to papers or "
            "authors by name inline when needed."
        )
        user_prompt = "\n\n".join(prompt_parts)

        answer = self.llm.generate_response(
            user_prompt=user_prompt,
            system_prompt=_REDUCE_SYSTEM_PROMPT,
            response_mime_type="text/plain",
            max_tokens=max_generation_tokens,
            temperature=0.3,
        )

        return {
            "answer": answer,
            "communities": [
                {
                    "community_id": c.get("community_id"),
                    "title": c.get("title"),
                    "theme": c.get("theme"),
                    "score": c.get("score", 0),
                    "contribution": c.get("contribution", ""),
                    "papers": c.get("paper_titles", []),
                }
                for c in survivors
            ],
            "candidate_count": len(candidates),
            "rewritten_query": retrieval_query if retrieval_query != query else None,
        }
