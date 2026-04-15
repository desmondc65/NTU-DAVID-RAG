"""
CLI: ingest a (PDF, Fortran) pair into GraphRAG's *own* database.

GraphRAG maintains its own storage tree under ``graph_db/`` (sibling to
the vector RAG's ``db/``) so the two systems can be populated, rebuilt,
and torn down independently. This script reuses the shared ingestion
and embedding orchestrators in ``utils/`` but targets the GraphRAG DB
path.

Usage
-----
    python -m graphRag.ingest --pdf PATH --fortran PATH [--db-path PATH]
                              [--data-dir PATH] [--no-profile]
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

DEFAULT_DB_PATH = PROJECT_ROOT / "graph_db"
DEFAULT_DATA_DIR = PROJECT_ROOT / "graph_data"


def main() -> None:
    parser = argparse.ArgumentParser(description="Ingest a paper into the GraphRAG database.")
    parser.add_argument("--pdf", required=True, help="Path to the PDF manuscript.")
    parser.add_argument("--fortran", required=True, help="Path to the companion Fortran source file.")
    parser.add_argument("--db-path", default=str(DEFAULT_DB_PATH),
                        help="GraphRAG database path (default: graph_db/).")
    parser.add_argument("--data-dir", default=str(DEFAULT_DATA_DIR),
                        help="Directory for ingest artefacts (default: graph_data/).")
    parser.add_argument("--no-profile", action="store_true",
                        help="Skip the paper-profile extraction step.")
    parser.add_argument("--verbose", action="store_true")
    args = parser.parse_args()

    logging.basicConfig(
        level=logging.DEBUG if args.verbose else logging.INFO,
        format="%(levelname)s %(name)s | %(message)s",
    )

    # Imports deferred so --help stays fast and torch-free.
    from utils.orchestrator.ingest_paper import ingest_paper_and_code
    from utils.orchestrator.store_to_db import store_ingested_data

    data_dir = Path(args.data_dir)
    data_dir.mkdir(parents=True, exist_ok=True)
    db_path = Path(args.db_path)
    db_path.mkdir(parents=True, exist_ok=True)

    ingest_result = ingest_paper_and_code(
        pdf_path=args.pdf,
        fortran_path=args.fortran,
        output_dir=data_dir,
        db_path=str(db_path),
    )

    store_result = store_ingested_data(
        ingest_result=ingest_result,
        db_path=db_path,
        build_profile=not args.no_profile,
    )

    print("\n── Ingest complete ──")
    print(f"  paper_dir: {ingest_result.get('paper_dir')}")
    for k, v in store_result.items():
        print(f"  {k}: {v}")
    print(
        "\nNext: build the graph with\n"
        f"    python -m graphRag.build_graph --db-path {db_path}"
    )


if __name__ == "__main__":
    main()
