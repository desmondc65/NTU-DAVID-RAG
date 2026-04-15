"""
Local (entity-anchored) query path for GraphRAG.

Steps
-----
1. Extract seed entities from the user query via LLM (canonical names).
2. Map each seed to the closest graph entity via cosine similarity over
   precomputed entity-name+description embeddings.
3. Grow a ``n_hop`` neighbourhood around the seeds in the undirected
   projection.
4. Collect the source chunks referenced by the subgraph nodes/edges;
   pull their text from the Qdrant chunk store.
5. Build an LLM prompt that exposes both the subgraph (as a structured
   list of entities and relationships) and the chunk evidence.

Reuses ``LocalLLMClient`` and the ``EmbeddingModel`` from the existing
``utils`` package.
"""
from __future__ import annotations

import logging
from typing import Any, Dict, List, Optional

import networkx as nx
import numpy as np

from utils.llm_clients.local_llm import LocalLLMClient
from utils.s2_embedding.embedder import EmbeddingModel
from utils.s2_embedding.qdrant_store import QdrantVectorStore

logger = logging.getLogger(__name__)


_SEED_SYSTEM_PROMPT = (
    "You extract canonical entity names from a user's question about a "
    "corpus of economics papers. Return ONLY valid JSON."
)


def _extract_seed_entities(query: str, llm: LocalLLMClient) -> List[str]:
    prompt = (
        f"Question: \"{query}\"\n\n"
        "List the 2-6 most important named entities or concepts the question "
        "is asking about (economic models, methods, datasets, key variables, "
        "authors). Use canonical short names (e.g. \"overlapping-generations "
        "model\", \"wealth inequality\", not full sentences). Return a JSON "
        "object {\"entities\": [str, ...]}."
    )
    try:
        raw = llm.generate_response(
            user_prompt=prompt,
            system_prompt=_SEED_SYSTEM_PROMPT,
            response_mime_type="application/json",
            max_tokens=256,
            temperature=0.0,
        )
    except Exception as exc:
        logger.warning("Seed extraction failed: %s", exc)
        return []
    if not isinstance(raw, dict):
        return []
    ents = raw.get("entities") or []
    if not isinstance(ents, list):
        return []
    out = [str(e).strip() for e in ents if str(e).strip()][:8]
    return out


def _cosine_topk(
    query_vec: np.ndarray,
    matrix: np.ndarray,
    top_k: int,
) -> List[int]:
    # Assume rows are L2-normalised by the embedder; if not, normalise here.
    q = query_vec / (np.linalg.norm(query_vec) + 1e-12)
    m_norm = np.linalg.norm(matrix, axis=1, keepdims=True) + 1e-12
    m = matrix / m_norm
    sims = m @ q
    idx = np.argsort(-sims)[:top_k]
    return [int(i) for i in idx]


def _grow_subgraph(g: nx.DiGraph, seeds: List[str], n_hop: int) -> List[str]:
    undirected = g.to_undirected(as_view=True)
    visited: set = set()
    frontier: set = {s for s in seeds if s in undirected}
    for _ in range(n_hop):
        next_frontier: set = set()
        for n in frontier:
            if n in visited:
                continue
            visited.add(n)
            next_frontier.update(undirected.neighbors(n))
        next_frontier -= visited
        frontier = next_frontier
    visited.update(frontier)
    return list(visited)


def _render_subgraph(g: nx.DiGraph, node_keys: List[str], max_edges: int = 60) -> str:
    if not node_keys:
        return "(empty subgraph)"
    node_set = set(node_keys)
    lines: List[str] = ["ENTITIES:"]
    for k in node_keys[:60]:
        attrs = g.nodes[k]
        desc = ""
        descs = attrs.get("descriptions") or []
        if descs:
            desc = f" — {descs[0]}"
        lines.append(f"  - [{attrs.get('type', '?')}] {attrs.get('name', k)}{desc}")
    lines.append("")
    lines.append("RELATIONSHIPS:")
    rendered = 0
    for u in node_keys:
        if rendered >= max_edges:
            break
        for v, data in g[u].items():
            if v not in node_set or rendered >= max_edges:
                continue
            d = data.get("description", "")
            extra = f" — {d}" if d else ""
            lines.append(
                f"  - {g.nodes[u].get('name', u)} --[{data.get('relationship_type', 'mentions')}]--> "
                f"{g.nodes[v].get('name', v)}{extra}"
            )
            rendered += 1
    return "\n".join(lines)


def _fetch_chunk_texts(
    store: QdrantVectorStore,
    chunk_ids: List[str],
    limit: int,
) -> List[Dict[str, Any]]:
    """Pull specific chunk records from Qdrant by ID."""
    if not chunk_ids:
        return []
    ids = chunk_ids[:limit]
    try:
        records = store.client.retrieve(
            collection_name=store.collection_name,
            ids=ids,
            with_payload=True,
            with_vectors=False,
        )
    except Exception as exc:
        logger.warning("Failed to fetch chunks by ID: %s", exc)
        return []
    out: List[Dict[str, Any]] = []
    for rec in records:
        payload = dict(rec.payload) if rec.payload else {}
        text = payload.pop("document", "")
        out.append({
            "id": rec.id,
            "text": text,
            "metadata": payload,
        })
    return out


def _collect_subgraph_chunks(g: nx.DiGraph, node_keys: List[str], cap: int = 30) -> List[str]:
    seen: List[str] = []
    seen_set: set = set()
    # Prefer within-community chunks (node-attached) first, then edge-attached.
    for n in node_keys:
        for cid in g.nodes[n].get("chunk_ids", []):
            if cid and cid not in seen_set:
                seen.append(cid)
                seen_set.add(cid)
                if len(seen) >= cap:
                    return seen
    node_set = set(node_keys)
    for u in node_keys:
        for v, data in g[u].items():
            if v not in node_set:
                continue
            for cid in data.get("chunk_ids", []):
                if cid and cid not in seen_set:
                    seen.append(cid)
                    seen_set.add(cid)
                    if len(seen) >= cap:
                        return seen
    return seen


def _format_chunks(chunks: List[Dict[str, Any]]) -> str:
    lines: List[str] = []
    for i, c in enumerate(chunks, 1):
        meta = c.get("metadata", {}) or {}
        paper = meta.get("paper_title", "")
        section = meta.get("section", "")
        header = f"[C{i}] Paper: {paper}" + (f" | Section: {section}" if section else "")
        text = (c.get("text") or "").strip()
        if len(text) > 1600:
            text = text[:1600] + "…"
        lines.append(header)
        lines.append(text)
        lines.append("")
    return "\n".join(lines).strip()


class LocalSearch:
    def __init__(
        self,
        graph: nx.DiGraph,
        chunk_store: QdrantVectorStore,
        embedder: EmbeddingModel,
        llm: LocalLLMClient,
        entity_embeddings: Optional[np.ndarray] = None,
        entity_order: Optional[List[str]] = None,
    ) -> None:
        self.g = graph
        self.store = chunk_store
        self.embedder = embedder
        self.llm = llm
        self.entity_embeddings = entity_embeddings
        self.entity_order = entity_order

    def _resolve_seeds(self, raw_seeds: List[str], top_per_seed: int = 2) -> List[str]:
        if not raw_seeds:
            return []
        if self.entity_embeddings is None or not self.entity_order:
            # Fallback: exact lowercase lookup.
            out = []
            for s in raw_seeds:
                key = s.strip().lower()
                if key in self.g.nodes and key not in out:
                    out.append(key)
            return out
        # Embed each seed, find closest entities.
        vectors = [self.embedder.embed_query(s) for s in raw_seeds]
        q_matrix = np.asarray(vectors, dtype=np.float32)
        resolved: List[str] = []
        for qv in q_matrix:
            idx = _cosine_topk(qv, self.entity_embeddings, top_k=top_per_seed)
            for i in idx:
                key = self.entity_order[i]
                if key in self.g.nodes and key not in resolved:
                    resolved.append(key)
        return resolved

    def search(
        self,
        query: str,
        n_hop: int = 1,
        max_chunks: int = 20,
        max_generation_tokens: int = 30_000,
    ) -> Dict[str, Any]:
        raw_seeds = _extract_seed_entities(query, self.llm)
        seed_nodes = self._resolve_seeds(raw_seeds)
        logger.info("Local seeds: %s -> %s", raw_seeds, seed_nodes)

        if not seed_nodes:
            return {
                "answer": "No matching entities were found in the knowledge graph for this question.",
                "seeds": raw_seeds,
                "subgraph_nodes": [],
                "chunks": [],
            }

        subgraph_nodes = _grow_subgraph(self.g, seed_nodes, n_hop=n_hop)
        # Sort by degree — central entities first.
        subgraph_nodes.sort(key=lambda n: -self.g.nodes[n].get("degree", 0))

        subgraph_text = _render_subgraph(self.g, subgraph_nodes)
        chunk_ids = _collect_subgraph_chunks(self.g, subgraph_nodes, cap=max_chunks)
        chunk_records = _fetch_chunk_texts(self.store, chunk_ids, limit=max_chunks)
        chunk_block = _format_chunks(chunk_records)

        system_prompt = (
            "You are an expert research assistant for academic economics. "
            "You are given a RELEVANT SUBGRAPH of the corpus knowledge graph "
            "and the SOURCE CHUNKS attached to its entities and relationships. "
            "Answer the user's question using this evidence only. Cite chunks "
            "as [C1], [C2] when you rely on specific passages. When "
            "summarising the graph structure itself, reference entities by "
            "name. If the evidence is insufficient, say so."
        )
        user_prompt = (
            f"<subgraph>\n{subgraph_text}\n</subgraph>\n\n"
            f"<chunks>\n{chunk_block}\n</chunks>\n\n"
            f"<question>\n{query}\n</question>"
        )

        answer = self.llm.generate_response(
            user_prompt=user_prompt,
            system_prompt=system_prompt,
            response_mime_type="text/plain",
            max_tokens=max_generation_tokens,
            temperature=0.3,
        )

        return {
            "answer": answer,
            "seeds": raw_seeds,
            "subgraph_nodes": [self.g.nodes[n].get("name", n) for n in subgraph_nodes],
            "chunks": chunk_records,
        }
