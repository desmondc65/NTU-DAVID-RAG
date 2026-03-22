"""
Interactive RAG query script.

Usage:
    CUDA_VISIBLE_DEVICES=2 python -m utils.s3_RAG.run_rag \
        --vector-store "data/.../vector_store" \
        --device cuda:0

    Enters an interactive loop where you can type queries and see
    hybrid-retrieved + reranked results.
"""

import argparse
import os
import textwrap

from dotenv import load_dotenv

from utils.s3_RAG.hybrid_rag import HybridRAG


def _print_results(results, query):
    """Pretty-print retrieval results."""
    print(f"\n{'─' * 70}")
    print(f"  Query: {query}")
    print(f"  Results: {len(results)}")
    print(f"{'─' * 70}")

    for i, r in enumerate(results, 1):
        meta = r.get("metadata", {})
        content_type = meta.get("content_type", "unknown")
        rerank_score = r.get("rerank_score", 0.0)
        rrf_score = r.get("rrf_score", 0.0)

        # Truncate text for display
        text_preview = r["text"][:200].replace("\n", " ")
        text_preview = textwrap.shorten(text_preview, width=200, placeholder="...")

        print(f"\n  [{i}] rerank={rerank_score:.4f} | rrf={rrf_score:.4f} | type={content_type}")

        # Show extra metadata for code
        if content_type == "code":
            file_name = meta.get("file_name", "")
            line_range = f"L{meta.get('line_start', '?')}-{meta.get('line_end', '?')}"
            print(f"      file={file_name} {line_range}")

        # Show page info for manuscript
        if content_type == "manuscript":
            pages = meta.get("page_indices", "")
            print(f"      pages={pages}")

        print(f"      {text_preview}")

    print(f"\n{'─' * 70}\n")


def main():
    # Load .env from project root
    load_dotenv()

    parser = argparse.ArgumentParser(
        description="Interactive hybrid RAG query interface"
    )
    parser.add_argument(
        "--vector-store",
        type=str,
        required=True,
        help="Path to ChromaDB persistent storage directory",
    )
    parser.add_argument(
        "--collection",
        type=str,
        default="rag_embeddings",
        help="ChromaDB collection name (default: rag_embeddings)",
    )
    parser.add_argument(
        "--embedding-model",
        type=str,
        default="BAAI/bge-large-en-v1.5",
        help="Dense embedding model (default: BAAI/bge-large-en-v1.5)",
    )
    parser.add_argument(
        "--reranker-model",
        type=str,
        default="BAAI/bge-reranker-v2-m3",
        help="Cross-encoder reranker model (default: BAAI/bge-reranker-v2-m3)",
    )
    parser.add_argument(
        "--device",
        type=str,
        default=None,
        help="Device for models, e.g. 'cuda:0' (default: auto-detect)",
    )
    parser.add_argument(
        "--top-k",
        type=int,
        default=10,
        help="Number of final results after reranking (default: 10)",
    )
    parser.add_argument(
        "--filter",
        type=str,
        choices=["manuscript", "code", "all"],
        default="all",
        help="Filter results by content type (default: all)",
    )

    args = parser.parse_args()

    # Initialize pipeline
    print("=" * 60)
    print("  Hybrid RAG Pipeline")
    print("  BM25 + Dense + BGE-Reranker-v2")
    print("=" * 60)
    print()

    rag = HybridRAG(
        vector_store_dir=args.vector_store,
        collection_name=args.collection,
        embedding_model=args.embedding_model,
        reranker_model=args.reranker_model,
        device=args.device,
    )

    where_filter = None
    if args.filter != "all":
        where_filter = {"content_type": args.filter}
        print(f"Filter: {args.filter} only")

    # Interactive loop
    print("Type your query (or 'quit' to exit, 'filter:code' / 'filter:manuscript' / 'filter:all' to change filter):\n")

    while True:
        try:
            query = input(">>> ").strip()
        except (EOFError, KeyboardInterrupt):
            print("\nExiting.")
            break

        if not query:
            continue

        if query.lower() in ("quit", "exit", "q"):
            print("Exiting.")
            break

        # Handle filter commands
        if query.lower().startswith("filter:"):
            filter_val = query.split(":", 1)[1].strip()
            if filter_val == "all":
                where_filter = None
                print("Filter: all (no filter)")
            elif filter_val in ("manuscript", "code"):
                where_filter = {"content_type": filter_val}
                print(f"Filter: {filter_val}")
            else:
                print(f"Unknown filter: {filter_val}. Use 'manuscript', 'code', or 'all'.")
            continue

        # Run hybrid retrieval
        results = rag.query(
            query=query,
            final_top_k=args.top_k,
            where_filter=where_filter,
        )

        _print_results(results, query)


if __name__ == "__main__":
    main()
