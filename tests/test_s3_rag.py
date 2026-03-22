"""
Tests for Phase 3: Hybrid RAG Retrieval Pipeline (s3_RAG)

Tests BM25 retriever, dense retriever, reranker, and full hybrid pipeline
using the existing vector store from Phase 2.
"""

import sys
import os
import time
from pathlib import Path

# Add parent directory to path for imports
sys.path.append(str(Path(__file__).parent.parent))

# Data paths
DATA_DIR = "data/Accounting for Wealth Concentration in the United States"
VECTOR_STORE_DIR = os.path.join(DATA_DIR, "vector_store")


def test_bm25_retriever():
    """Test BM25 indexing and lexical retrieval."""
    print("\n=== Test: BM25 Sparse Retriever ===")
    try:
        from utils.s3_RAG.bm25_retriever import BM25Retriever

        bm25 = BM25Retriever()

        # Index some test documents
        texts = [
            "REAL(prec) PARAMETER :: ALPHA = 0.27 ! Capital share",
            "The Gini coefficient for net worth is 0.84",
            "SUBROUTINE compute_gini calculates wealth inequality",
            "Earnings heterogeneity drives wealth concentration",
            "INTEGER PARAMETER NGRIDA = 513 ! Number of points on asset grid",
        ]
        metadatas = [
            {"content_type": "code"},
            {"content_type": "manuscript"},
            {"content_type": "code"},
            {"content_type": "manuscript"},
            {"content_type": "code"},
        ]
        ids = [f"doc_{i}" for i in range(len(texts))]

        bm25.index_documents(texts, metadatas, ids)
        print(f"  Indexed {len(texts)} documents")

        # Test exact lexical match
        results = bm25.retrieve("ALPHA capital share", top_k=3)
        assert len(results) > 0, "No results returned"
        assert results[0]["id"] == "doc_0", f"Wrong top result: {results[0]['id']}"
        print(f"  Query 'ALPHA capital share': top={results[0]['id']} score={results[0]['score']:.4f}")

        # Test Fortran variable name match
        results2 = bm25.retrieve("NGRIDA asset grid", top_k=3)
        assert len(results2) > 0
        assert results2[0]["id"] == "doc_4"
        print(f"  Query 'NGRIDA asset grid': top={results2[0]['id']} score={results2[0]['score']:.4f}")

        # Test metadata filtering
        results3 = bm25.retrieve("wealth", top_k=5, where_filter={"content_type": "manuscript"})
        for r in results3:
            assert r["metadata"]["content_type"] == "manuscript", "Filter not applied"
        print(f"  Filtered (manuscript) query: {len(results3)} results")

        print("  ✓ PASSED")
        return True
    except Exception as e:
        print(f"  ✗ FAILED: {e}")
        return False


def test_bm25_from_chromadb():
    """Test BM25 indexing from existing ChromaDB data."""
    print("\n=== Test: BM25 from ChromaDB ===")
    try:
        from utils.s3_RAG.dense_retriever import DenseRetriever
        from utils.s3_RAG.bm25_retriever import BM25Retriever

        # Load docs from ChromaDB
        dense = DenseRetriever(
            vector_store_dir=VECTOR_STORE_DIR, device="cuda:0"
        )
        all_docs = dense.get_all_documents()
        assert len(all_docs["ids"]) > 0, "No documents in ChromaDB"
        print(f"  Documents from ChromaDB: {len(all_docs['ids'])}")

        # Build BM25 index
        bm25 = BM25Retriever()
        bm25.index_documents(
            texts=all_docs["documents"],
            metadatas=all_docs["metadatas"],
            ids=all_docs["ids"],
        )

        # Test Fortran-specific query
        results = bm25.retrieve("SUBROUTINE BRACKET01 SRCHFIVE01", top_k=5)
        assert len(results) > 0
        print(f"  Query 'SUBROUTINE BRACKET01': {len(results)} results, top score={results[0]['score']:.4f}")
        print(f"    top type: {results[0]['metadata'].get('content_type')}")

        # Test academic term query
        results2 = bm25.retrieve("Gini coefficient wealth distribution", top_k=5)
        assert len(results2) > 0
        print(f"  Query 'Gini coefficient': {len(results2)} results, top score={results2[0]['score']:.4f}")

        print("  ✓ PASSED")
        return True
    except Exception as e:
        print(f"  ✗ FAILED: {e}")
        return False


def test_dense_retriever():
    """Test dense vector retrieval from existing ChromaDB."""
    print("\n=== Test: Dense Vector Retriever ===")
    try:
        from utils.s3_RAG.dense_retriever import DenseRetriever

        dense = DenseRetriever(
            vector_store_dir=VECTOR_STORE_DIR, device="cuda:0"
        )

        # Semantic query
        results = dense.retrieve("What drives wealth concentration?", top_k=5)
        assert len(results) == 5, f"Expected 5 results, got {len(results)}"
        print(f"  Semantic query: {len(results)} results")
        print(f"    top score: {results[0]['score']:.4f}")
        print(f"    top type: {results[0]['metadata'].get('content_type')}")

        # Filtered query
        results_code = dense.retrieve(
            "value function iteration", top_k=3,
            where_filter={"content_type": "code"},
        )
        for r in results_code:
            assert r["metadata"]["content_type"] == "code"
        print(f"  Code-filtered query: {len(results_code)} results, top score={results_code[0]['score']:.4f}")

        print("  ✓ PASSED")
        return True
    except Exception as e:
        print(f"  ✗ FAILED: {e}")
        return False


def test_reranker():
    """Test cross-encoder reranker scoring and sorting."""
    print("\n=== Test: Cross-Encoder Reranker ===")
    try:
        from utils.s3_RAG.reranker import Reranker

        reranker = Reranker(device="cuda:0")
        print(f"  Model: {reranker.model_name}")

        # Create mock results with known relevance
        query = "What is the Gini coefficient of wealth?"
        mock_results = [
            {"id": "irrelevant", "text": "SUBROUTINE BRACKET01 solves asset decision rules using golden section search", "metadata": {}},
            {"id": "relevant", "text": "The Gini coefficient for net worth is 0.84, whereas it is 0.64 for earnings and 0.66 for income.", "metadata": {}},
            {"id": "partial", "text": "Wealth concentration is driven by earnings heterogeneity and capital income risk.", "metadata": {}},
        ]

        reranked = reranker.rerank(query, mock_results, top_k=3)

        assert len(reranked) == 3
        # The directly relevant passage should be ranked first
        assert reranked[0]["id"] == "relevant", f"Expected 'relevant' first, got '{reranked[0]['id']}'"
        print(f"  Reranked order: {[r['id'] for r in reranked]}")
        for r in reranked:
            print(f"    {r['id']}: rerank_score={r['rerank_score']:.4f}")

        # Scores should be in descending order
        scores = [r["rerank_score"] for r in reranked]
        assert scores == sorted(scores, reverse=True), "Scores not in descending order"

        print("  ✓ PASSED")
        return True
    except Exception as e:
        print(f"  ✗ FAILED: {e}")
        return False


def test_hybrid_rag_pipeline():
    """Test full hybrid RAG pipeline end-to-end."""
    print("\n=== Test: Full Hybrid RAG Pipeline ===")
    try:
        from utils.s3_RAG.hybrid_rag import HybridRAG

        rag = HybridRAG(
            vector_store_dir=VECTOR_STORE_DIR,
            device="cuda:0",
        )

        # Test 1: General academic query
        print("\n  Query 1: 'What drives wealth concentration?'")
        results1 = rag.query("What drives wealth concentration?", final_top_k=5)
        assert len(results1) > 0, "No results returned"
        assert len(results1) <= 5
        assert "rerank_score" in results1[0], "Missing rerank_score"
        print(f"    Results: {len(results1)}")
        for i, r in enumerate(results1):
            print(f"    [{i+1}] rerank={r['rerank_score']:.4f} | type={r['metadata'].get('content_type')} | {r['text'][:80]}...")

        # Test 2: Exact Fortran variable query (BM25 should shine)
        print("\n  Query 2: 'NGRIDA MAXAGE RETAGE parameter'")
        results2 = rag.query("NGRIDA MAXAGE RETAGE parameter", final_top_k=5)
        assert len(results2) > 0
        # Should return code chunks
        code_results = [r for r in results2 if r["metadata"].get("content_type") == "code"]
        print(f"    Results: {len(results2)} ({len(code_results)} code)")
        assert len(code_results) > 0, "BM25 should find Fortran variable names in code"

        # Test 3: With content type filter
        print("\n  Query 3: 'earnings' (filter: manuscript)")
        results3 = rag.query(
            "earnings heterogeneity",
            final_top_k=3,
            where_filter={"content_type": "manuscript"},
        )
        for r in results3:
            assert r["metadata"]["content_type"] == "manuscript", "Filter not applied"
        print(f"    Results: {len(results3)} (all manuscript)")

        # Test 4: Code-filtered query
        print("\n  Query 4: 'policy function solver' (filter: code)")
        results4 = rag.query(
            "policy function solver subroutine",
            final_top_k=3,
            where_filter={"content_type": "code"},
        )
        for r in results4:
            assert r["metadata"]["content_type"] == "code", "Filter not applied"
        print(f"    Results: {len(results4)} (all code)")
        print(f"    Top rerank score: {results4[0]['rerank_score']:.4f}")

        print("\n  ✓ PASSED")
        return True
    except Exception as e:
        print(f"  ✗ FAILED: {e}")
        return False


def test_rrf_fusion():
    """Test Reciprocal Rank Fusion merging logic."""
    print("\n=== Test: Reciprocal Rank Fusion ===")
    try:
        from utils.s3_RAG.hybrid_rag import _reciprocal_rank_fusion

        list1 = [
            {"id": "A", "text": "doc A", "metadata": {}, "score": 0.9},
            {"id": "B", "text": "doc B", "metadata": {}, "score": 0.8},
            {"id": "C", "text": "doc C", "metadata": {}, "score": 0.7},
        ]
        list2 = [
            {"id": "B", "text": "doc B", "metadata": {}, "score": 0.95},
            {"id": "D", "text": "doc D", "metadata": {}, "score": 0.85},
            {"id": "A", "text": "doc A", "metadata": {}, "score": 0.75},
        ]

        fused = _reciprocal_rank_fusion([list1, list2])

        # B appears at rank 2 in list1 and rank 1 in list2, should have highest RRF
        # A appears at rank 1 in list1 and rank 3 in list2
        ids = [r["id"] for r in fused]
        print(f"  Fused order: {ids}")
        rrf_scores_str = [f"{r['rrf_score']:.6f}" for r in fused]
        print(f"  RRF scores: {rrf_scores_str}")

        # B should be first (appears high in both lists)
        assert fused[0]["id"] == "B", f"Expected B first, got {fused[0]['id']}"
        # All 4 unique docs should be present
        assert len(fused) == 4, f"Expected 4 unique docs, got {len(fused)}"
        # No duplicates
        assert len(set(ids)) == len(ids), "Duplicates found"

        print("  ✓ PASSED")
        return True
    except Exception as e:
        print(f"  ✗ FAILED: {e}")
        return False


def run_all_tests():
    """Run all Phase 3 tests and report results."""
    print("=" * 60)
    print("Phase 3: Hybrid RAG Retrieval Tests")
    print(f"Time: {time.strftime('%Y-%m-%d %H:%M:%S')}")
    print("=" * 60)

    results = {
        "BM25 Retriever": test_bm25_retriever(),
        "BM25 from ChromaDB": test_bm25_from_chromadb(),
        "Dense Retriever": test_dense_retriever(),
        "Reranker": test_reranker(),
        "RRF Fusion": test_rrf_fusion(),
        "Hybrid RAG Pipeline": test_hybrid_rag_pipeline(),
    }

    print("\n" + "=" * 60)
    print("Test Results Summary")
    print("=" * 60)

    for test_name, passed in results.items():
        status = "✓ PASSED" if passed else "✗ FAILED"
        print(f"  {test_name}: {status}")

    total = len(results)
    passed = sum(results.values())
    print(f"\n  Total: {passed}/{total} tests passed")
    print("=" * 60)

    return all(results.values())


if __name__ == "__main__":
    success = run_all_tests()
    sys.exit(0 if success else 1)
