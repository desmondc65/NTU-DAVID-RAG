import sys
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[1]
if str(REPO_ROOT) not in sys.path:
    sys.path.insert(0, str(REPO_ROOT))

from utils.orchestrator.store_to_db import store_ingested_data


def main():
    ingest_result = {
        "md_path": str(REPO_ROOT / "tests" / "ingest_results" / "Manuscript" / "auto" / "Manuscript.md"),
        "content_list_json": str(REPO_ROOT / "tests" / "ingest_results" / "Manuscript" / "auto" / "Manuscript_content_list.json"),
        "metadata_json": str(REPO_ROOT / "tests" / "ingest_results" / "metadata.json"),
        "fortran_digest_json": str(REPO_ROOT / "tests" / "ingest_results" / "benchmark_digest.json"),
    }
    db_path = REPO_ROOT / "db"

    print(f"Content list: {ingest_result['content_list_json']}")
    print(f"Fortran digest: {ingest_result['fortran_digest_json']}")
    print(f"DB path: {db_path}")

    result = store_ingested_data(
        ingest_result=ingest_result,
        db_path=db_path,
    )

    print("\n── Result ──")
    for k, v in result.items():
        print(f"  {k}: {v}")

    # Verify paper registry was created
    registry_path = db_path / "paper_registry.json"
    if registry_path.exists():
        import json
        with open(registry_path) as f:
            registry = json.load(f)
        print(f"\n── Paper Registry ({len(registry)} papers) ──")
        for entry in registry:
            print(f"  • {entry['paper_title']} by {entry['authors']}")
    else:
        print("\n❌ Paper registry not found!")


if __name__ == "__main__":
    main()
