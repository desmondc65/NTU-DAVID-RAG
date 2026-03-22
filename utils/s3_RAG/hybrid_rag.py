"""
Hybrid RAG Pipeline: BM25 (Sparse) + Dense (Vector) + Cross-Encoder Reranker.

Orchestrates the full retrieval flow:
1. BM25 sparse retrieval for lexical matching
2. Dense vector retrieval for semantic understanding
3. Reciprocal Rank Fusion to merge results
4. Cross-encoder reranking for final relevance scoring
"""

from typing import Dict, List, Optional

from utils.s3_RAG.bm25_retriever import BM25Retriever
from utils.s3_RAG.dense_retriever import DenseRetriever
from utils.s3_RAG.reranker import Reranker


def _reciprocal_rank_fusion(
    result_lists: List[List[Dict]],
    k: int = 60,
) -> List[Dict]:
    """
    Merge multiple ranked result lists using Reciprocal Rank Fusion (RRF).

    RRF score for document d = sum over all lists of 1 / (k + rank(d))
    This is a proven method for combining heterogeneous retrieval signals.

    Args:
        result_lists: List of ranked result lists (each is a list of dicts).
        k: RRF constant (default 60, per the original paper).

    Returns:
        Merged list sorted by RRF score, deduplicated by document ID.
    """
    rrf_scores = {}  # type: Dict[str, float]
    doc_map = {}  # type: Dict[str, Dict]

    for results in result_lists:
        for rank, result in enumerate(results, start=1):
            doc_id = result["id"]
            rrf_scores[doc_id] = rrf_scores.get(doc_id, 0.0) + 1.0 / (k + rank)
            # Keep the first occurrence's data
            if doc_id not in doc_map:
                doc_map[doc_id] = result

    # Sort by RRF score descending
    sorted_ids = sorted(rrf_scores.keys(), key=lambda x: rrf_scores[x], reverse=True)

    merged = []
    for doc_id in sorted_ids:
        entry = doc_map[doc_id].copy()
        entry["rrf_score"] = rrf_scores[doc_id]
        merged.append(entry)

    return merged


class HybridRAG:
    """
    Full hybrid retrieval pipeline:
    BM25 + Dense + Reciprocal Rank Fusion + Cross-Encoder Reranker.
    """

    def __init__(
        self,
        vector_store_dir: str,
        collection_name: str = "rag_embeddings",
        embedding_model: str = "BAAI/bge-large-en-v1.5",
        reranker_model: str = "BAAI/bge-reranker-v2-m3",
        device: Optional[str] = None,
    ):
        """
        Args:
            vector_store_dir: Path to ChromaDB persistent storage.
            collection_name: Collection name in ChromaDB.
            embedding_model: Dense embedding model name.
            reranker_model: Cross-encoder reranker model name.
            device: Device for inference ('cuda:0', 'cpu', None).
        """
        print("Loading dense retriever...")
        self.dense = DenseRetriever(
            vector_store_dir=vector_store_dir,
            collection_name=collection_name,
            embedding_model=embedding_model,
            device=device,
        )

        print("Loading BM25 index...")
        self.bm25 = BM25Retriever()
        self._build_bm25_from_chromadb()

        print("Loading reranker...")
        self.reranker = Reranker(model_name=reranker_model, device=device)

        print("✓ Hybrid RAG pipeline ready.\n")

    def _build_bm25_from_chromadb(self) -> None:
        """Build BM25 index from all documents in the ChromaDB collection."""
        all_docs = self.dense.get_all_documents()
        if not all_docs["ids"]:
            print("  Warning: No documents found in ChromaDB collection.")
            return

        self.bm25.index_documents(
            texts=all_docs["documents"],
            metadatas=all_docs["metadatas"],
            ids=all_docs["ids"],
        )
        print(f"  → BM25 indexed {len(all_docs['ids'])} documents")

    def query(
        self,
        query: str,
        sparse_top_k: int = 50,
        dense_top_k: int = 50,
        final_top_k: int = 10,
        where_filter: Optional[Dict] = None,
    ) -> List[Dict]:
        """
        Run the full hybrid retrieval pipeline.

        1. BM25 retrieves top sparse_top_k by lexical match
        2. Dense retrieves top dense_top_k by semantic similarity
        3. Results are fused via Reciprocal Rank Fusion
        4. Top 50 fused results are reranked by cross-encoder

        Args:
            query: The user's search query.
            sparse_top_k: Number of BM25 results.
            dense_top_k: Number of dense results.
            final_top_k: Number of results after reranking.
            where_filter: Optional metadata filter.

        Returns:
            List of reranked result dicts sorted by relevance.
        """
        # Step 1: Sparse retrieval (BM25)
        bm25_results = self.bm25.retrieve(
            query=query, top_k=sparse_top_k, where_filter=where_filter
        )

        # Step 2: Dense retrieval (vector)
        dense_results = self.dense.retrieve(
            query=query, top_k=dense_top_k, where_filter=where_filter
        )

        # Step 3: Reciprocal Rank Fusion
        fused = _reciprocal_rank_fusion([bm25_results, dense_results])

        # Take top 50 for reranking (cross-encoder is expensive)
        candidates = fused[:50]

        # Step 4: Cross-encoder reranking
        reranked = self.reranker.rerank(
            query=query,
            results=candidates,
            top_k=final_top_k,
        )

        return reranked
