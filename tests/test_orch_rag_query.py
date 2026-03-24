"""
Test the RAG query engine with various prompts covering different content types.

Uses the Qdrant DB populated by test_orch_store_to_db.py (in db/).
Requires the local LLM to be running.
"""
import sys
import textwrap
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[1]
if str(REPO_ROOT) not in sys.path:
    sys.path.insert(0, str(REPO_ROOT))

from utils.orchestrator.rag_query import RAGQueryEngine


DB_PATH = REPO_ROOT / "db"

# ── Test prompts designed to exercise different content types ─────────────
TEST_QUERIES = [
    {
        "label": "Manuscript text (economics concept)",
        "query": "What drives wealth concentration in the United States?",
        "top_k": 5,
    },
    {
        "label": "Table retrieval",
        "query": "What are the cross-sectional distributions of income, earnings, and net worth?",
        "top_k": 5,
    },
    {
        "label": "Equation retrieval",
        "query": "What is the household budget constraint in the model?",
        "top_k": 5,
    },
    {
        "label": "Fortran function retrieval",
        "query": "How is the value function computed in the Fortran benchmark code?",
        "top_k": 5,
    },
    {
        "label": "Cross-type query (paper + code)",
        "query": "How do earnings heterogeneity and labor income risk affect the wealth distribution? Is this implemented in the Fortran code?",
        "top_k": 8,
    },
]


def _separator(title: str):
    print(f"\n{'═' * 70}")
    print(f"  {title}")
    print(f"{'═' * 70}")


def main():
    print("Initializing RAG query engine...")
    engine = RAGQueryEngine(db_path=DB_PATH)

    # Show papers in DB
    papers = engine.list_papers()
    _separator(f"Papers in DB ({len(papers)})")
    for p in papers:
        print(f"  • {p['paper_title']} by {p['authors']}")

    # Run each test query
    for i, test in enumerate(TEST_QUERIES, 1):
        _separator(f"Test {i}/{len(TEST_QUERIES)}: {test['label']}")
        print(f"  Query: {test['query']}")

        result = engine.query(
            user_query=test["query"],
            top_k=test["top_k"],
        )

        # Print sources
        print(f"\n  Sources ({len(result['sources'])}):")
        for j, s in enumerate(result["sources"], 1):
            meta = s.get("metadata", {})
            ct = meta.get("content_type", "?")
            score = s.get("rerank_score", 0)
            preview = s["text"][:120].replace("\n", " ")
            print(f"    [{j}] type={ct} | score={score:.4f} | {preview}...")

        # Print answer (wrapped for readability)
        print(f"\n  Answer:")
        wrapped = textwrap.fill(result["answer"], width=80, initial_indent="    ", subsequent_indent="    ")
        print(wrapped)

    _separator("All tests complete")


if __name__ == "__main__":
    main()
