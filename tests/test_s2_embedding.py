"""
Tests for Phase 2: Embedding Pipeline (s2_embedding)

Tests chunking, embedding, and vector store functionality
using the existing processed data files.
"""

import sys
import os
import json
import time
from pathlib import Path

# Add parent directory to path for imports
sys.path.append(str(Path(__file__).parent.parent))

# Data paths
DATA_DIR = "data/Accounting for Wealth Concentration in the United States"
MANUSCRIPT_JSON = os.path.join(
    DATA_DIR,
    "manuscript_parsed_mineru/Manuscript/hybrid_auto/Manuscript_content_list.json",
)
FORTRAN_JSON = os.path.join(DATA_DIR, "RAG_Chunks/fortran_chunks.json")
VECTOR_STORE_DIR = os.path.join(DATA_DIR, "vector_store")


def test_chunker_manuscript():
    """Test manuscript chunking filters text-only and produces valid chunks."""
    print("\n=== Test: Manuscript Chunking ===")
    try:
        from utils.s2_embedding.chunker import chunk_manuscript

        chunks = chunk_manuscript(MANUSCRIPT_JSON)

        assert len(chunks) > 0, "No chunks produced"
        print(f"  Chunks produced: {len(chunks)}")

        # Verify structure
        for c in chunks[:3]:
            assert "text" in c, "Missing 'text' key"
            assert "metadata" in c, "Missing 'metadata' key"
            assert c["metadata"]["content_type"] == "manuscript"
            assert "page_indices" in c["metadata"]
            assert "chunk_idx" in c["metadata"]

        # Verify no non-text types leaked through
        with open(MANUSCRIPT_JSON, "r") as f:
            raw = json.load(f)
        non_text_types = {e["type"] for e in raw if e.get("type") != "text"}
        print(f"  Non-text types filtered out: {non_text_types}")

        for c in chunks:
            for nt in non_text_types:
                # Headers, footers, page numbers should not appear as chunk content
                assert c["metadata"]["content_type"] != nt

        # Check that chunks have reasonable length
        avg_len = sum(len(c["text"]) for c in chunks) / len(chunks)
        print(f"  Avg chunk length: {avg_len:.0f} chars")
        assert avg_len > 50, "Chunks are too short"

        print("  ✓ PASSED")
        return True
    except Exception as e:
        print(f"  ✗ FAILED: {e}")
        return False


def test_chunker_fortran():
    """Test Fortran code chunking reads files and prepends summaries."""
    print("\n=== Test: Fortran Code Chunking ===")
    try:
        from utils.s2_embedding.chunker import chunk_fortran

        chunks = chunk_fortran(FORTRAN_JSON)

        assert len(chunks) > 0, "No chunks produced"
        print(f"  Chunks produced: {len(chunks)}")

        # Verify structure
        for c in chunks:
            assert "text" in c
            assert c["metadata"]["content_type"] == "code"
            assert "file_name" in c["metadata"]
            assert "summary" in c["metadata"]
            assert "line_start" in c["metadata"]
            assert "line_end" in c["metadata"]

        # Verify summary is prepended
        first = chunks[0]
        assert "[Summary]:" in first["text"], "Summary not prepended to chunk"
        assert "[File]:" in first["text"], "File name not in chunk"
        print(f"  First chunk file: {first['metadata']['file_name']}")
        print(f"  First chunk lines: {first['metadata']['line_start']}-{first['metadata']['line_end']}")

        # Verify we have chunks from multiple files
        files = set(c["metadata"]["file_name"] for c in chunks)
        print(f"  Unique files chunked: {len(files)}")
        assert len(files) > 1, "Expected chunks from multiple files"

        print("  ✓ PASSED")
        return True
    except Exception as e:
        print(f"  ✗ FAILED: {e}")
        return False


def test_embedder():
    """Test embedding model loads and produces correct dimensionality."""
    print("\n=== Test: Embedding Model ===")
    try:
        from utils.s2_embedding.embedder import EmbeddingModel

        model = EmbeddingModel(device="cuda:0")
        print(f"  Model: {model.model_name}")
        print(f"  BGE model: {model.is_bge}")

        # Test document embedding
        docs = [
            "Wealth concentration in the United States",
            "REAL(prec) PARAMETER :: ALPHA = 0.27",
        ]
        embeddings = model.embed_documents(docs, show_progress=False)
        assert len(embeddings) == 2
        assert len(embeddings[0]) == 1024, f"Expected 1024-dim, got {len(embeddings[0])}"
        print(f"  Embedding dim: {len(embeddings[0])}")

        # Test query embedding (should apply BGE prefix)
        q_emb = model.embed_query("What is wealth concentration?")
        assert len(q_emb) == 1024
        print(f"  Query embedding dim: {len(q_emb)}")

        # Verify normalization (should be unit vectors)
        import math
        norm = math.sqrt(sum(x ** 2 for x in embeddings[0]))
        assert abs(norm - 1.0) < 0.01, f"Embedding not normalized: norm={norm}"
        print(f"  Embedding norm: {norm:.6f} (expected ~1.0)")

        print("  ✓ PASSED")
        return True
    except Exception as e:
        print(f"  ✗ FAILED: {e}")
        return False


def test_vector_store():
    """Test ChromaDB vector store loads and queries existing data."""
    print("\n=== Test: Vector Store ===")
    try:
        from utils.s2_embedding.vector_store import VectorStore

        store = VectorStore(persist_dir=VECTOR_STORE_DIR)
        count = store.count
        assert count > 0, "Vector store is empty"
        print(f"  Documents in store: {count}")

        # Test query with a dummy embedding (1024-dim zeros)
        dummy = [0.0] * 1024
        results = store.query(dummy, n_results=3)
        assert len(results["ids"][0]) == 3
        print(f"  Query returned: {len(results['ids'][0])} results")

        # Test filtered query
        results_code = store.query(
            dummy, n_results=3, where_filter={"content_type": "code"}
        )
        for meta in results_code["metadatas"][0]:
            assert meta["content_type"] == "code", "Filter not applied"
        print(f"  Filtered (code) query: {len(results_code['ids'][0])} results")

        results_ms = store.query(
            dummy, n_results=3, where_filter={"content_type": "manuscript"}
        )
        for meta in results_ms["metadatas"][0]:
            assert meta["content_type"] == "manuscript", "Filter not applied"
        print(f"  Filtered (manuscript) query: {len(results_ms['ids'][0])} results")

        print("  ✓ PASSED")
        return True
    except Exception as e:
        print(f"  ✗ FAILED: {e}")
        return False


def test_end_to_end_embedding_query():
    """Test embedding a query and retrieving from vector store."""
    print("\n=== Test: End-to-End Embed + Query ===")
    try:
        from utils.s2_embedding.embedder import EmbeddingModel
        from utils.s2_embedding.vector_store import VectorStore

        model = EmbeddingModel(device="cuda:0")
        store = VectorStore(persist_dir=VECTOR_STORE_DIR)

        # Semantic query
        q_emb = model.embed_query("wealth distribution Gini coefficient")
        results = store.query(q_emb, n_results=5)

        assert len(results["ids"][0]) == 5
        top_doc = results["documents"][0][0]
        top_score = 1.0 - results["distances"][0][0]
        print(f"  Top score: {top_score:.4f}")
        print(f"  Top doc preview: {top_doc[:100]}...")
        assert top_score > 0.5, f"Top score too low: {top_score}"

        # Code-specific query
        q_emb2 = model.embed_query("subroutine compute_gini")
        results2 = store.query(q_emb2, n_results=3, where_filter={"content_type": "code"})
        assert len(results2["ids"][0]) > 0
        print(f"  Code query results: {len(results2['ids'][0])}")

        print("  ✓ PASSED")
        return True
    except Exception as e:
        print(f"  ✗ FAILED: {e}")
        return False


def run_all_tests():
    """Run all Phase 2 tests and report results."""
    print("=" * 60)
    print("Phase 2: Embedding Pipeline Tests")
    print(f"Time: {time.strftime('%Y-%m-%d %H:%M:%S')}")
    print("=" * 60)

    results = {
        "Manuscript Chunking": test_chunker_manuscript(),
        "Fortran Chunking": test_chunker_fortran(),
        "Embedding Model": test_embedder(),
        "Vector Store": test_vector_store(),
        "End-to-End Embed+Query": test_end_to_end_embedding_query(),
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
