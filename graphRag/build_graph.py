"""
CLI: build (or rebuild) the GraphRAG artefacts for a database.

Usage
-----
    python -m graphRag.build_graph [--db-path PATH] [--skip-fortran]
                                   [--paper TITLE ...] [--max-chunks N]

The database is expected to already contain chunks produced by
``utils.orchestrator.store_to_db`` (Qdrant collection ``rag_embeddings``).
"""
from __future__ import annotations

import argparse
import logging
import sys
from pathlib import Path

CURRENT_DIR = Path(__file__).resolve().parent
PROJECT_ROOT = CURRENT_DIR.parent
if str(PROJECT_ROOT) not in sys.path:
    sys.path.insert(0, str(PROJECT_ROOT))

from graphRag.graph_rag import GraphRAGEngine  # noqa: E402

# GraphRAG maintains its OWN database (separate from utils/ vector RAG).
DEFAULT_DB_PATH = PROJECT_ROOT / "graph_db"


def main() -> None:
    parser = argparse.ArgumentParser(description="Build the GraphRAG knowledge graph.")
    parser.add_argument("--db-path", default=str(DEFAULT_DB_PATH))
    parser.add_argument("--paper", action="append", default=None,
                        help="Restrict extraction to these paper titles (repeatable).")
    parser.add_argument("--skip-fortran", action="store_true",
                        help="Exclude fortran_* content_types from extraction.")
    parser.add_argument("--max-chunks", type=int, default=None,
                        help="Cap on chunks processed (debug).")
    parser.add_argument("--verbose", action="store_true")
    args = parser.parse_args()

    logging.basicConfig(
        level=logging.DEBUG if args.verbose else logging.INFO,
        format="%(levelname)s %(name)s | %(message)s",
    )

    engine = GraphRAGEngine(db_path=args.db_path)
    try:
        stats = engine.build(
            paper_filter=args.paper,
            skip_fortran=args.skip_fortran,
            max_chunks=args.max_chunks,
        )
    finally:
        engine.close()

    print("\n── Build complete ──")
    for k, v in stats.items():
        print(f"  {k}: {v}")


if __name__ == "__main__":
    main()
