"""
Orchestrator: RAG-augmented query pipeline.

Takes a user query, retrieves relevant context from the Qdrant vector store
(populated by ``store_to_db``), builds a context-enriched prompt, and sends
it to the local LLM for generation.

Uses:
- Dense retrieval via ``QdrantVectorStore`` + ``EmbeddingModel``
- BM25 sparse retrieval for lexical matching
- Reciprocal Rank Fusion to merge results
- Cross-encoder reranking for final relevance scoring
- ``LocalLLMClient`` for LLM generation
"""
from __future__ import annotations

import json
import logging
import os
import sys
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
from utils.s3_RAG.bm25_retriever import BM25Retriever
from utils.s3_RAG.reranker import Reranker
from utils.llm_clients.local_llm import LocalLLMClient
from utils.orchestrator.paper_profiler import (
    PROFILE_COLLECTION,
    compute_profile_overlap,
    format_profile_block,
)
from utils.orchestrator.query_router import classify_query

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)


def _resolve_torch_device(preferred: Optional[str], fallback: str = "cpu") -> str:
    """Resolve runtime device with a safe fallback if CUDA is unavailable."""
    candidate = (preferred or "").strip()
    if not candidate:
        return fallback

    if candidate.startswith("cuda"):
        try:
            import torch
            if torch.cuda.is_available():
                return candidate
            logger.warning("Requested device '%s' but CUDA is unavailable. Falling back to '%s'.", candidate, fallback)
            return fallback
        except Exception as exc:
            logger.warning("Could not validate CUDA device '%s' (%s). Falling back to '%s'.", candidate, exc, fallback)
            return fallback

    return candidate


# ── RAG retriever (Qdrant-based) ─────────────────────────────────────────

class QdrantDenseRetriever:
    """Dense vector retrieval backed by Qdrant."""

    def __init__(
        self,
        qdrant_dir: str,
        collection_name: str = "rag_embeddings",
        embedding_model: str = _DEFAULT_MODEL,
        device: Optional[str] = None,
    ):
        self.store = QdrantVectorStore(
            persist_dir=qdrant_dir,
            collection_name=collection_name,
        )
        self.embedder = EmbeddingModel(
            model_name=embedding_model,
            device=device,
        )

    def retrieve(
        self,
        query: str,
        top_k: int = 50,
        where_filter: Optional[Dict] = None,
    ) -> List[Dict]:
        """Retrieve top-k documents by vector similarity."""
        query_embedding = self.embedder.embed_query(query)
        results = self.store.query(
            query_embedding=query_embedding,
            n_results=top_k,
            where_filter=where_filter,
        )
        output = []
        for i in range(len(results["ids"])):
            output.append({
                "id": results["ids"][i],
                "text": results["documents"][i],
                "metadata": results["metadatas"][i],
                "score": results["scores"][i],
            })
        return output

    def get_all_documents(self) -> Dict:
        """Scroll all documents from collection (for BM25 indexing)."""
        all_points = []
        offset = None
        while True:
            points, next_offset = self.store.client.scroll(
                collection_name=self.store.collection_name,
                limit=256,
                offset=offset,
                with_payload=True,
                with_vectors=False,
            )
            all_points.extend(points)
            if next_offset is None:
                break
            offset = next_offset

        ids = []
        documents = []
        metadatas = []
        for pt in all_points:
            payload = dict(pt.payload) if pt.payload else {}
            ids.append(pt.id)
            documents.append(payload.pop("document", ""))
            metadatas.append(payload)

        return {"ids": ids, "documents": documents, "metadatas": metadatas}

    def close(self) -> None:
        """Release Qdrant resources."""
        self.store.close()


# ── Reciprocal Rank Fusion ───────────────────────────────────────────────

def _reciprocal_rank_fusion(
    result_lists: List[List[Dict]],
    k: int = 60,
) -> List[Dict]:
    """Merge ranked result lists via RRF."""
    rrf_scores: Dict[str, float] = {}
    doc_map: Dict[str, Dict] = {}

    for results in result_lists:
        for rank, result in enumerate(results, start=1):
            doc_id = result["id"]
            rrf_scores[doc_id] = rrf_scores.get(doc_id, 0.0) + 1.0 / (k + rank)
            if doc_id not in doc_map:
                doc_map[doc_id] = result

    sorted_ids = sorted(rrf_scores.keys(), key=lambda x: rrf_scores[x], reverse=True)
    merged = []
    for doc_id in sorted_ids:
        entry = doc_map[doc_id].copy()
        entry["rrf_score"] = rrf_scores[doc_id]
        merged.append(entry)
    return merged


# ── Paper-diversity enforcement ──────────────────────────────────────────

def _diversify_results(results: List[Dict], top_k: int = 10) -> List[Dict]:
    """
    Ensure results include chunks from diverse papers via round-robin selection.

    Prevents all top-k results from clustering on a single paper, which is
    critical for comparative / cross-paper queries.
    """
    from collections import OrderedDict

    paper_groups: OrderedDict[str, List[Dict]] = OrderedDict()
    for r in results:
        paper = r.get("metadata", {}).get("paper_title", "_unknown_")
        paper_groups.setdefault(paper, []).append(r)

    diversified: List[Dict] = []
    seen: set = set()
    round_idx = 0

    while len(diversified) < top_k:
        added_this_round = False
        for _paper, group in paper_groups.items():
            if round_idx < len(group):
                entry = group[round_idx]
                if entry["id"] not in seen:
                    diversified.append(entry)
                    seen.add(entry["id"])
                    added_this_round = True
                    if len(diversified) >= top_k:
                        break
        if not added_this_round:
            break
        round_idx += 1

    return diversified


# ── Context builder ──────────────────────────────────────────────────────

def _format_manuscript_chunk(r: Dict, ref_id: str = "") -> str:
    """Format a single manuscript text chunk.

    ``ref_id`` is accepted for backwards compatibility but no longer
    rendered — answers cite by paper title + section instead.
    """
    del ref_id
    meta = r.get("metadata", {})
    section = meta.get("section", "")
    pages = meta.get("page_indices", "")
    header_parts = ["Passage"]
    if section:
        header_parts.append(f"— Section: {section}")
    if pages:
        header_parts.append(f"(pages {pages})")
    header = " ".join(header_parts)
    return f"{header}\n{r['text']}"


def _format_equation_chunk(r: Dict, ref_id: str = "") -> str:
    """Format an equation chunk with LaTeX."""
    del ref_id
    meta = r.get("metadata", {})
    section = meta.get("section", "")
    latex = meta.get("equation_latex", "")
    header = "Equation"
    if section:
        header += f" in {section}"
    lines = [header]
    if latex:
        lines.append(f"$$\n{latex}\n$$")
    lines.append(f"Context: {r['text']}")
    return "\n".join(lines)


def _format_table_chunk(r: Dict, ref_id: str = "") -> str:
    """Format a table chunk with caption and body."""
    del ref_id
    meta = r.get("metadata", {})
    caption = meta.get("table_caption", "")
    table_body = meta.get("table_body", "")
    header = "Table"
    if caption:
        header += f": {caption}"
    lines = [header]
    if table_body:
        lines.append(table_body)
    lines.append(f"Description: {r['text']}")
    return "\n".join(lines)


def _format_image_chunk(r: Dict, ref_id: str = "") -> str:
    """Format an image/figure chunk."""
    del ref_id
    meta = r.get("metadata", {})
    section = meta.get("section", "")
    header = "Figure"
    if section:
        header += f" in {section}"
    return f"{header}\n{r['text']}"


def _format_fortran_chunk(r: Dict, ref_id: str = "") -> str:
    """Format a Fortran code chunk with structured metadata."""
    del ref_id
    meta = r.get("metadata", {})
    func_name = meta.get("function_name", "")
    kind = meta.get("kind", "")
    purpose = meta.get("purpose", "") or meta.get("core_purpose", "")
    calls = meta.get("calls", "") or meta.get("dependencies", "")
    called_by = meta.get("called_by", "")
    econ = meta.get("economic_concepts", "")
    algorithm = meta.get("algorithm", "")
    inputs = meta.get("inputs", "")
    outputs = meta.get("outputs", "")

    label = kind.replace("_", " ").title() if kind else "Function"
    header = f"{label}: {func_name}"
    lines = [header]
    if purpose:
        lines.append(f"  Purpose: {purpose}")
    if econ:
        lines.append(f"  Economic concepts: {econ}")
    if algorithm:
        lines.append(f"  Algorithm: {algorithm}")
    if inputs:
        lines.append(f"  Inputs: {inputs}")
    if outputs:
        lines.append(f"  Outputs: {outputs}")
    if calls:
        lines.append(f"  Calls: {calls}")
    if called_by:
        lines.append(f"  Called by: {called_by}")
    lines.append(r["text"])
    return "\n".join(lines)


_CONTENT_FORMATTERS = {
    "manuscript": _format_manuscript_chunk,
    "equation": _format_equation_chunk,
    "table": _format_table_chunk,
    "image": _format_image_chunk,
    "fortran_function": _format_fortran_chunk,
    "fortran_section": _format_fortran_chunk,
    "fortran_architecture": _format_fortran_chunk,
}


def _build_context(
    results: List[Dict],
    max_context_tokens: int = 4000,
    profiles: Optional[List[Dict]] = None,
) -> str:
    """
    Build a structured context string from retrieval results.

    Groups results by paper, separates Fortran code into its own section,
    preserves document order within each paper, and adds a source inventory
    so the LLM knows what papers and content types are available.

    When ``profiles`` is non-empty (global-query path), a PAPER PROFILES
    section is prepended so the LLM can reason about paper identities
    (models, methods, concepts) before seeing individual chunks.
    """
    from collections import OrderedDict

    # ── Classify results ────────────────────────────────────────────────
    paper_groups: OrderedDict[str, List[Dict]] = OrderedDict()
    fortran_results: List[Dict] = []
    other_results: List[Dict] = []

    for r in results:
        meta = r.get("metadata", {})
        content_type = meta.get("content_type", "unknown")
        paper = meta.get("paper_title", "")

        if content_type in ("fortran_function", "fortran_section", "fortran_architecture"):
            fortran_results.append(r)
        elif paper:
            paper_groups.setdefault(paper, []).append(r)
        else:
            other_results.append(r)

    # Sort within each paper by sequence_idx for reading order
    for group in paper_groups.values():
        group.sort(key=lambda x: x.get("metadata", {}).get("sequence_idx", 0))

    # ── Source inventory ────────────────────────────────────────────────
    inventory_lines = ["# SOURCE INVENTORY"]
    for pidx, (paper, group) in enumerate(paper_groups.items(), 1):
        authors = group[0].get("metadata", {}).get("authors", "")
        types = sorted({r.get("metadata", {}).get("content_type", "?") for r in group})
        auth_str = f" by {authors}" if authors else ""
        inventory_lines.append(
            f"  Paper {pidx}: \"{paper}\"{auth_str} — "
            f"{len(group)} passages ({', '.join(types)})"
        )
    if fortran_results:
        fortran_papers = sorted({
            r.get("metadata", {}).get("paper_title", "unknown")
            for r in fortran_results
        })
        inventory_lines.append(
            f"  Fortran code: {len(fortran_results)} units from "
            + ", ".join(f"\"{p}\"" for p in fortran_papers)
        )
    inventory = "\n".join(inventory_lines)

    # ── Build formatted blocks ──────────────────────────────────────────
    blocks: List[str] = [inventory, ""]
    token_count = _estimate_tokens(inventory)

    # Profile section for global queries — prepended so the LLM can anchor
    # each paper's identity before reading individual chunks. Profiles are
    # identified by paper title in the rendered block (no bracket tags —
    # those read as opaque noise in answers).
    if profiles:
        profile_header = "# PAPER PROFILES (for cross-paper comparison)"
        header_tokens = _estimate_tokens(profile_header)
        if token_count + header_tokens <= max_context_tokens:
            blocks.append(profile_header)
            token_count += header_tokens
            for p in profiles:
                block = format_profile_block(p.get("metadata", {}) or p)
                block_tokens = _estimate_tokens(block)
                if token_count + block_tokens > max_context_tokens:
                    break
                blocks.append(block)
                token_count += block_tokens
            blocks.append("")

        # Deterministic pairwise overlap — lets the LLM quote concrete
        # shared fields instead of having to infer them from prose.
        overlap_block = compute_profile_overlap(profiles)
        if overlap_block:
            overlap_tokens = _estimate_tokens(overlap_block)
            if token_count + overlap_tokens <= max_context_tokens:
                blocks.append(overlap_block)
                token_count += overlap_tokens
                blocks.append("")

    # Paper sections
    for paper, group in paper_groups.items():
        paper_header = f"# PAPER: {paper}"
        authors = group[0].get("metadata", {}).get("authors", "")
        if authors:
            paper_header += f"\n# Authors: {authors}"

        header_tokens = _estimate_tokens(paper_header)
        if token_count + header_tokens > max_context_tokens:
            break
        blocks.append(paper_header)
        token_count += header_tokens

        for r in group:
            content_type = r.get("metadata", {}).get("content_type", "unknown")
            formatter = _CONTENT_FORMATTERS.get(content_type, _format_manuscript_chunk)
            block = formatter(r)

            block_tokens = _estimate_tokens(block)
            if token_count + block_tokens > max_context_tokens:
                break
            blocks.append(block)
            token_count += block_tokens

        blocks.append("")  # blank line between papers

    # Fortran section
    if fortran_results:
        fortran_header = "# COMPUTATIONAL IMPLEMENTATION (Fortran)"
        header_tokens = _estimate_tokens(fortran_header)
        if token_count + header_tokens <= max_context_tokens:
            blocks.append(fortran_header)
            token_count += header_tokens

            for r in fortran_results:
                content_type = r.get("metadata", {}).get("content_type", "unknown")
                formatter = _CONTENT_FORMATTERS.get(content_type, _format_fortran_chunk)
                block = formatter(r)

                block_tokens = _estimate_tokens(block)
                if token_count + block_tokens > max_context_tokens:
                    break
                blocks.append(block)
                token_count += block_tokens

    # Other (no paper title) — rare fallback
    if other_results:
        for r in other_results:
            block = _format_manuscript_chunk(r)
            block_tokens = _estimate_tokens(block)
            if token_count + block_tokens > max_context_tokens:
                break
            blocks.append(block)
            token_count += block_tokens

    return "\n\n".join(blocks)


def _estimate_tokens(text: str) -> int:
    """Rough token estimate: ~1.33 tokens per whitespace word."""
    return int(len(text.split()) * 1.33)


def _format_conversation_history(
    history: Optional[List[Dict[str, str]]],
    max_turns: int = 20,
    max_chars_per_turn: int = 1200,
) -> str:
    """Format a bounded chat history block for prompt conditioning."""
    if not history:
        return ""

    lines: List[str] = []
    for turn in history[-max_turns:]:
        if not isinstance(turn, dict):
            continue
        role = str(turn.get("role", "")).strip().lower()
        content = str(turn.get("content", "")).strip()
        if role not in {"user", "assistant"} or not content:
            continue
        speaker = "User" if role == "user" else "Assistant"
        lines.append(f"{speaker}: {content[:max_chars_per_turn]}")
    return "\n".join(lines)


# ── Main RAG query function ──────────────────────────────────────────────

class RAGQueryEngine:
    """
    End-to-end RAG query engine:
    Qdrant dense retrieval + BM25 + RRF + reranking + LLM generation.
    """

    def __init__(
        self,
        db_path: Union[str, Path],
        collection_name: str = "rag_embeddings",
        embedding_model: str = _DEFAULT_MODEL,
        reranker_model: str = "BAAI/bge-reranker-v2-m3",
        model_name: Optional[str] = None,
        base_url: Optional[str] = None,
        api_key: Optional[str] = None,
        device: Optional[str] = None,
        embedding_device: Optional[str] = None,
        reranker_device: Optional[str] = None,
    ):
        db_path = Path(db_path)
        qdrant_dir = str(db_path / "qdrant_data")

        default_gpu = os.getenv("RAG_DEVICE", "cuda:0")
        embedding_pref = embedding_device or device or os.getenv("RAG_EMBEDDING_DEVICE", default_gpu)
        reranker_pref = reranker_device or device or os.getenv("RAG_RERANKER_DEVICE", default_gpu)

        self.embedding_device = _resolve_torch_device(embedding_pref)
        self.reranker_device = _resolve_torch_device(reranker_pref)
        logger.info("Embedding device: %s | Reranker device: %s", self.embedding_device, self.reranker_device)

        logger.info("Loading dense retriever (Qdrant)…")
        self.dense = QdrantDenseRetriever(
            qdrant_dir=qdrant_dir,
            collection_name=collection_name,
            embedding_model=embedding_model,
            device=self.embedding_device,
        )

        # Profile collection — share the dense client (Qdrant local path locks
        # the storage directory so we must not open a second client on it).
        try:
            existing_collections = {
                c.name for c in self.dense.store.client.get_collections().collections
            }
            self.profile_enabled = PROFILE_COLLECTION in existing_collections
        except Exception as exc:
            logger.warning("Could not list Qdrant collections: %s", exc)
            self.profile_enabled = False
        if self.profile_enabled:
            logger.info("Profile collection '%s' detected — global-query routing enabled.", PROFILE_COLLECTION)
        else:
            logger.info("Profile collection missing — global queries will fall back to local retrieval.")

        logger.info("Building BM25 index from Qdrant…")
        self.bm25 = BM25Retriever()
        self._build_bm25()

        logger.info("Loading reranker…")
        self.reranker = Reranker(model_name=reranker_model, device=self.reranker_device)

        self.model_name = model_name or os.getenv("LLM_MODEL_NAME", "gemma4:31b")
        self.base_url = base_url or os.getenv("LOCAL_LLM_BASE_URL", "http://localhost:11434/v1")
        self.api_key = api_key or os.getenv("LOCAL_LLM_API_KEY", "ollama")

        self.llm = LocalLLMClient(
            model_name=self.model_name,
            base_url=self.base_url,
            api_key=self.api_key,
        )

        # Load paper registry for context
        registry_path = db_path / "paper_registry.json"
        self.papers = []
        if registry_path.exists():
            with open(registry_path, "r", encoding="utf-8") as f:
                self.papers = json.load(f)

        logger.info("✅  RAG query engine ready (%d papers in registry).", len(self.papers))

    def _build_bm25(self) -> None:
        """Build BM25 index from all documents in Qdrant."""
        all_docs = self.dense.get_all_documents()
        if not all_docs["ids"]:
            logger.warning("No documents in Qdrant — BM25 index empty.")
            return
        self.bm25.index_documents(
            texts=all_docs["documents"],
            metadatas=all_docs["metadatas"],
            ids=all_docs["ids"],
        )
        logger.info("BM25 indexed %d documents.", len(all_docs["ids"]))

    # ── Multi-query expansion ───────────────────────────────────────────

    def _expand_query(self, query: str) -> List[str]:
        """Use the LLM to generate diverse sub-queries for broader retrieval."""
        try:
            result = self.llm.generate_response(
                user_prompt=(
                    f"Generate 3 diverse search queries to find relevant passages "
                    f"in academic economics papers for this question:\n\n"
                    f"\"{query}\"\n\n"
                    f"Each query should target a different aspect or use different "
                    f"vocabulary. Return a JSON object with key \"queries\" "
                    f"containing an array of query strings."
                ),
                system_prompt=(
                    "You generate search queries for an academic RAG system. "
                    "Return ONLY valid JSON, no other text."
                ),
                max_tokens=256,
                temperature=0.4,
            )
            queries = result.get("queries", []) if isinstance(result, dict) else []
            return [q for q in queries if isinstance(q, str) and q.strip()][:3]
        except Exception as exc:
            logger.warning("Query expansion failed (%s) — using original query only.", exc)
            return []

    # ── Neighbor chunk expansion ─────────────────────────────────────────

    def _expand_with_neighbors(
        self, results: List[Dict], n_neighbors: int = 1,
    ) -> List[Dict]:
        """
        Expand retrieved chunks with adjacent chunks from the same paper.

        Uses ``sequence_idx`` to find neighbors in the BM25 document store,
        providing the LLM with more continuous text for better reasoning.
        """
        # Build lookup: (paper_title, sequence_idx) → document info
        paper_seq_lookup: Dict[tuple, Dict] = {}
        for i, meta in enumerate(self.bm25.metadatas):
            paper = meta.get("paper_title", "")
            seq = meta.get("sequence_idx", -1)
            if paper and seq >= 0:
                paper_seq_lookup[(paper, seq)] = {
                    "id": self.bm25.doc_ids[i],
                    "text": self.bm25.documents[i],
                    "metadata": meta,
                }

        seen_ids = {r["id"] for r in results}
        expanded = list(results)

        for r in results:
            meta = r.get("metadata", {})
            paper = meta.get("paper_title", "")
            seq = meta.get("sequence_idx", -1)
            if not paper or seq < 0:
                continue

            for offset in range(-n_neighbors, n_neighbors + 1):
                if offset == 0:
                    continue
                key = (paper, seq + offset)
                if key in paper_seq_lookup:
                    neighbor = paper_seq_lookup[key]
                    if neighbor["id"] not in seen_ids:
                        seen_ids.add(neighbor["id"])
                        entry = neighbor.copy()
                        # Score slightly below parent so ordering is preserved
                        entry["rerank_score"] = r.get("rerank_score", 0) - 0.01
                        expanded.append(entry)

        return expanded

    # ── Profile retrieval (global queries) ──────────────────────────────

    def _retrieve_profiles(self, query: str, top_k: int = 5) -> List[Dict]:
        """Vector-search the paper_profiles collection for candidate papers."""
        if not self.profile_enabled:
            return []
        try:
            query_emb = self.dense.embedder.embed_query(query)
            points = self.dense.store.client.query_points(
                collection_name=PROFILE_COLLECTION,
                query=query_emb,
                limit=top_k,
                with_payload=True,
            ).points
        except Exception as exc:
            logger.warning("Profile retrieval failed: %s", exc)
            return []

        out: List[Dict] = []
        for pt in points:
            payload = dict(pt.payload) if pt.payload else {}
            doc = payload.pop("document", "")
            out.append({
                "id": pt.id,
                "text": doc,
                "metadata": payload,
                "score": pt.score,
                "paper_title": payload.get("paper_title", ""),
            })
        return out

    def retrieve_global(
        self,
        query: str,
        focus_concepts: Optional[List[str]] = None,
        profile_top_k: int = 6,
        chunks_per_paper: int = 4,
    ) -> Dict[str, List[Dict]]:
        """
        Profile-first retrieval for comparative / cross-document queries.

        1. Rank papers against the profile index (paper identities).
        2. For each candidate paper, retrieve top-N chunks via filtered hybrid
           retrieval — guarantees balanced per-paper evidence.

        Returns
        -------
        dict with keys:
            - ``profiles``: list of candidate paper profile records
            - ``chunks``: list of chunks aggregated across all candidates
        """
        # Enrich the query with focus concepts so the profile vector captures
        # the comparison axis, not just the interrogative phrasing.
        profile_query = query
        if focus_concepts:
            profile_query = f"{query}\nConcepts: {', '.join(focus_concepts)}"

        profiles = self._retrieve_profiles(profile_query, top_k=profile_top_k)
        if not profiles:
            logger.info("No profiles retrieved — falling back to local pipeline.")
            return {"profiles": [], "chunks": []}

        logger.info(
            "Global route: %d candidate papers (%s)",
            len(profiles),
            ", ".join(p.get("paper_title", "?") for p in profiles),
        )

        # Per-paper filtered retrieval — hybrid BM25 + dense, capped per paper.
        aggregated: List[Dict] = []
        for p in profiles:
            title = p.get("paper_title") or ""
            if not title:
                continue
            where = {"paper_title": title}
            try:
                bm25_hits = self.bm25.retrieve(
                    query=query, top_k=chunks_per_paper * 3, where_filter=where,
                )
            except Exception as exc:
                logger.debug("BM25 paper-filtered retrieval failed for '%s': %s", title, exc)
                bm25_hits = []
            try:
                dense_hits = self.dense.retrieve(
                    query=query, top_k=chunks_per_paper * 3, where_filter=where,
                )
            except Exception as exc:
                logger.debug("Dense paper-filtered retrieval failed for '%s': %s", title, exc)
                dense_hits = []
            fused = _reciprocal_rank_fusion([bm25_hits, dense_hits])
            if not fused:
                continue
            reranked = self.reranker.rerank(
                query=query, results=fused[: chunks_per_paper * 3], top_k=chunks_per_paper,
            )
            aggregated.extend(reranked)

        return {"profiles": profiles, "chunks": aggregated}

    # ── Retrieval ────────────────────────────────────────────────────────

    def retrieve(
        self,
        query: str,
        sparse_top_k: int = 50,
        dense_top_k: int = 50,
        final_top_k: int = 20,
        where_filter: Optional[Dict] = None,
        expand_queries: bool = True,
        ensure_diversity: bool = True,
    ) -> List[Dict]:
        """
        Hybrid retrieval: BM25 + Dense + RRF + Reranker.

        Parameters
        ----------
        expand_queries : bool
            When True, uses LLM to generate sub-queries for broader coverage.
        ensure_diversity : bool
            When True, enforces round-robin paper diversity in final results.
        """
        # 1. Build query set (original + optional expansions)
        queries = [query]
        if expand_queries:
            sub_queries = self._expand_query(query)
            if sub_queries:
                queries.extend(sub_queries)
                logger.info("Expanded to %d queries: %s", len(queries), queries)

        # 2. Retrieve from all queries
        all_result_lists: List[List[Dict]] = []
        for q in queries:
            bm25_results = self.bm25.retrieve(query=q, top_k=sparse_top_k, where_filter=where_filter)
            dense_results = self.dense.retrieve(query=q, top_k=dense_top_k, where_filter=where_filter)
            all_result_lists.extend([bm25_results, dense_results])

        # 3. Fuse all result lists via RRF
        fused = _reciprocal_rank_fusion(all_result_lists)
        candidates = fused[:50]

        # 4. Rerank against original query
        rerank_top = max(final_top_k * 2, 30) if ensure_diversity else final_top_k
        reranked = self.reranker.rerank(query=query, results=candidates, top_k=rerank_top)

        # 5. Enforce paper diversity if requested
        if ensure_diversity:
            return _diversify_results(reranked, top_k=final_top_k)
        return reranked[:final_top_k]

    def query(
        self,
        user_query: str,
        top_k: int = 10,
        conversation_history: Optional[List[Dict[str, str]]] = None,
        where_filter: Optional[Dict] = None,
        max_context_tokens: int = 192000,
        max_generation_tokens: int = 60000,
        temperature: float = 0.3,
    ) -> Dict:
        """
        Full RAG pipeline: retrieve → build context → generate answer.

        Prompt architecture:
        - **system_prompt**: Role identity + behavioral instructions (compact,
          always visible to the model's attention).
        - **user_prompt**: Retrieved context (grouped by paper, then Fortran) →
          conversation history → user question.  Placing context before the
          question lets the model attend to evidence first.

        Parameters
        ----------
        user_query : str
            The user's question.
        top_k : int
            Number of retrieved passages to include as context.
        where_filter : dict, optional
            Metadata filter (e.g. ``{"content_type": "manuscript"}``).
        max_context_tokens / max_generation_tokens / temperature
            LLM generation parameters.

        Returns
        -------
        dict with keys:
            - ``answer``: The LLM-generated response.
            - ``sources``: List of retrieved source dicts.
            - ``context``: The context string sent to the LLM.
        """
        # 1. Route query: local vs global
        route = classify_query(user_query, self.llm) if self.profile_enabled else {"scope": "local", "focus_concepts": []}
        logger.info("Query scope: %s | focus: %s", route.get("scope"), route.get("focus_concepts"))

        profiles: List[Dict] = []
        if route.get("scope") == "global" and self.profile_enabled and where_filter is None:
            # Global route: profile-first retrieval with per-paper chunk budgets.
            global_result = self.retrieve_global(
                query=user_query,
                focus_concepts=route.get("focus_concepts"),
                profile_top_k=6,
                chunks_per_paper=4,
            )
            profiles = global_result["profiles"]
            sources = global_result["chunks"]
            # Fall back to local retrieval if the global path produced nothing.
            if not sources:
                logger.info("Global route empty — falling back to local retrieval.")
                sources = self.retrieve(
                    query=user_query,
                    final_top_k=top_k,
                    where_filter=where_filter,
                )
        else:
            logger.info("Retrieving context for: '%s'", user_query)
            sources = self.retrieve(
                query=user_query,
                final_top_k=top_k,
                where_filter=where_filter,
            )

        # 2. Expand with neighboring chunks for context continuity
        sources = self._expand_with_neighbors(sources, n_neighbors=1)

        # 3. Build context (prepend profile blocks for global queries)
        context = _build_context(
            sources,
            max_context_tokens=max_context_tokens,
            profiles=profiles,
        )
        history_block = _format_conversation_history(conversation_history)

        # 4. System prompt — identity and instructions only
        system_prompt = (
            "You are an expert research assistant specializing in economics and "
            "computational modeling. Your knowledge base contains academic economics "
            "papers and their companion Fortran implementations.\n\n"
            "## Instructions\n"
            "- Answer ONLY based on the retrieved context provided. Do not use outside knowledge.\n"
            "- CITATIONS: refer to papers by their TITLE (in quotes) or by a short author-year form "
            "derived from the provided authors (e.g. \"Nishiyama (2018)\"). DO NOT use bracket tags "
            "like [1], [2], [P1], [P2] — they are noise to the reader. If you must pinpoint a "
            "specific passage, reference it as 'Section X of \"Paper Title\"' instead.\n"
            "- When a PAPER PROFILES section is present, the question is comparative.\n"
            "    - First consult the 'CROSS-PAPER OVERLAP ANALYSIS' block (if present) — it lists "
            "deterministic pairwise intersections of model families, methods, and concepts across the "
            "candidate papers. Report these overlaps EXPLICITLY, naming each paper by title.\n"
            "    - Do not claim 'no two papers share a model' unless the overlap analysis block is "
            "empty. Papers that merely mention related prior work by other authors do NOT count as "
            "overlap — overlap means the two papers themselves use the same model family.\n"
            "- When the question spans multiple papers, structure your answer with explicit comparisons: "
            "similarities, differences in models, assumptions, or findings. Always use the paper "
            "titles, not tags.\n"
            "- When discussing Fortran code, explain what the code computes economically, "
            "not just its programming logic. Link subroutines back to the equations or model "
            "sections they implement.\n"
            "- For equations, reproduce the LaTeX when it clarifies the answer.\n"
            "- For tables, reference specific rows/columns and interpret the economic meaning.\n"
            "- If the context does not contain enough information to answer, say so explicitly "
            "and suggest what kind of source might help.\n\n"
            "## Formatting\n"
            "- Use markdown headers (##, ###) to organize multi-part answers.\n"
            "- Inline math: $a_t = b_t$  |  Display math: $$a_t = b_t$$\n"
            "- Do not use \\\\(...\\\\) or \\\\[...\\\\] delimiters.\n"
        )

        # 5. User prompt — context → history → question
        user_parts: List[str] = []

        # Context block
        user_parts.append(
            "<retrieved_context>\n"
            f"{context}\n"
            "</retrieved_context>"
        )

        # Conversation history (if any)
        if history_block:
            user_parts.append(
                "<conversation_history>\n"
                f"{history_block}\n"
                "</conversation_history>"
            )

        # The actual question — placed last so it's closest to the response
        user_parts.append(
            f"<question>\n{user_query}\n</question>"
        )

        user_prompt = "\n\n".join(user_parts)

        logger.info("Sending augmented prompt to LLM (%d context chars)…", len(context))
        answer = self.llm.generate_response(
            user_prompt=user_prompt,
            system_prompt=system_prompt,
            max_tokens=max_generation_tokens,
            temperature=temperature,
            response_mime_type="text/plain",
        )

        return {
            "answer": answer,
            "sources": sources,
            "context": context,
        }

    def list_papers(self) -> List[Dict]:
        """Return the paper registry for frontend display."""
        return self.papers

    def close(self) -> None:
        """Release local resources held by the engine."""
        self.dense.close()


# ── CLI / manual test ─────────────────────────────────────────────────────

if __name__ == "__main__":
    db_path = PROJECT_ROOT / "db"

    engine = RAGQueryEngine(db_path=db_path)

    # Show papers in DB
    papers = engine.list_papers()
    print(f"\n── Papers in DB ({len(papers)}) ──")
    for p in papers:
        print(f"  • {p['paper_title']} by {p['authors']}")

    # Test query
    test_query = "What drives wealth concentration in the United States?"
    print(f"\n── Query: {test_query} ──")

    result = engine.query(test_query, top_k=5)

    print(f"\n── Answer ──\n{result['answer']}")
    print(f"\n── Sources ({len(result['sources'])}) ──")
    for i, s in enumerate(result["sources"], 1):
        meta = s.get("metadata", {})
        print(f"  [{i}] type={meta.get('content_type')} | score={s.get('rerank_score', 0):.4f} | {s['text'][:100]}...")
