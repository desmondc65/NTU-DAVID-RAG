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

from utils.s2_embedding.embedder import EmbeddingModel
from utils.s2_embedding.qdrant_store import QdrantVectorStore
from utils.s3_RAG.bm25_retriever import BM25Retriever
from utils.s3_RAG.reranker import Reranker
from utils.llm_clients.local_llm import LocalLLMClient

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
        embedding_model: str = "BAAI/bge-large-en-v1.5",
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

def _build_context(results: List[Dict], max_context_tokens: int = 4000) -> str:
    """
    Build a context string from retrieval results for the LLM prompt.

    Results from the same paper are sorted by ``sequence_idx`` so the
    context preserves the original document ordering.  Rich metadata is
    included for non-text items (LaTeX for equations, table body/caption,
    image paths).
    """
    from collections import OrderedDict

    # ── Group by paper, preserving first-seen order ──────────────────────
    paper_groups: OrderedDict = OrderedDict()
    other_results: List[Dict] = []  # fortran / no-paper items

    for r in results:
        meta = r.get("metadata", {})
        paper = meta.get("paper_title", "")
        if paper:
            paper_groups.setdefault(paper, []).append(r)
        else:
            other_results.append(r)

    # Sort each paper group by sequence_idx to preserve document order
    ordered_results: List[Dict] = []
    for paper, group in paper_groups.items():
        group.sort(key=lambda x: x.get("metadata", {}).get("sequence_idx", 0))
        ordered_results.extend(group)
    ordered_results.extend(other_results)

    # ── Format each result ───────────────────────────────────────────────
    lines = []
    token_count = 0

    for i, r in enumerate(ordered_results, 1):
        meta = r.get("metadata", {})
        content_type = meta.get("content_type", "unknown")
        paper = meta.get("paper_title", "")

        header_parts = [f"[{i}] type={content_type}"]
        if paper:
            header_parts.append(f"paper=\"{paper}\"")

        # --- body text beyond the index key ---
        extra_lines = []

        if content_type == "fortran_function":
            func_name = meta.get("function_name", "")
            purpose = meta.get("core_purpose", "")
            header_parts.append(f"function={func_name}")
            if purpose:
                header_parts.append(f"purpose=\"{purpose}\"")
            deps = meta.get("dependencies", "")
            if deps:
                extra_lines.append(f"Dependencies: {deps}")
            key_vars = meta.get("key_variables", "")
            if key_vars:
                extra_lines.append(f"Key variables: {key_vars}")

        elif content_type == "equation":
            latex = meta.get("equation_latex", "")
            if latex:
                extra_lines.append(f"LaTeX: {latex}")

        elif content_type == "table":
            caption = meta.get("table_caption", "")
            if caption:
                header_parts.append(f"caption={caption}")
            table_body = meta.get("table_body", "")
            if table_body:
                extra_lines.append(f"Table content: {table_body}")

        elif content_type == "image":
            img_path = meta.get("img_path", "")
            if img_path:
                header_parts.append(f"img_path={img_path}")

        elif content_type == "manuscript":
            pages = meta.get("page_indices", "")
            if pages:
                header_parts.append(f"pages={pages}")

        header = " | ".join(header_parts)
        body = r["text"]
        # Label description explicitly for non-text items
        if content_type in ("table", "equation", "image"):
            body = f"Description: {body}"
        if extra_lines:
            body += "\n" + "\n".join(extra_lines)
        block = f"--- {header} ---\n{body}\n"

        block_tokens = int(len(block.split()) * 1.33)
        if token_count + block_tokens > max_context_tokens:
            break

        lines.append(block)
        token_count += block_tokens

    return "\n".join(lines)


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
        embedding_model: str = "BAAI/bge-large-en-v1.5",
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

        logger.info("Building BM25 index from Qdrant…")
        self.bm25 = BM25Retriever()
        self._build_bm25()

        logger.info("Loading reranker…")
        self.reranker = Reranker(model_name=reranker_model, device=self.reranker_device)

        self.model_name = model_name or os.getenv("LLM_MODEL_NAME", "qwen2.5-vl-72b-instruct")
        self.base_url = base_url or os.getenv("LOCAL_LLM_BASE_URL", "http://localhost:8000/v1")
        self.api_key = api_key or os.getenv("LOCAL_LLM_API_KEY", "local-dev-key")

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
        max_context_tokens: int = 128000,
        max_generation_tokens: int = 60000,
        temperature: float = 0.3,
    ) -> Dict:
        """
        Full RAG pipeline: retrieve → build context → generate answer.

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
        # 1. Retrieve
        logger.info("Retrieving context for: '%s'", user_query)
        sources = self.retrieve(
            query=user_query,
            final_top_k=top_k,
            where_filter=where_filter,
        )

        # 2. Expand with neighboring chunks for context continuity
        sources = self._expand_with_neighbors(sources, n_neighbors=1)

        # 3. Build context
        context = _build_context(sources, max_context_tokens=max_context_tokens)
        history_block = _format_conversation_history(conversation_history)
        history_section = ""
        if history_block:
            history_section = (
                f"\n=== CONVERSATION HISTORY ===\n{history_block}\n=== END HISTORY ===\n"
            )

        # 4. Generate
        system_prompt = (
            "You are an expert research assistant for economics and computational modeling. "
            "Answer the user's question based on the retrieved context below. "
            "Cite specific passages, tables, equations, or Fortran functions when relevant. "
            "When the question involves comparing across papers, explicitly identify similarities "
            "and differences between the papers' models, assumptions, or findings. "
            "When writing mathematical expressions, format inline math with single dollar delimiters like $a_t = b_t$ "
            "and display math with double dollar delimiters like $$a_t = b_t$$. "
            "Do not use \\(...\\) or \\[...\\] delimiters. "
            "If the context does not contain enough information, say so clearly."
            f"{history_section}\n"
            f"=== RETRIEVED CONTEXT ===\n{context}\n=== END CONTEXT ==="
        )

        logger.info("Sending augmented prompt to LLM (%d context chars)…", len(context))
        answer = self.llm.generate_response(
            user_prompt=user_query,
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
