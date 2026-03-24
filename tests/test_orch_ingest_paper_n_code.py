import sys
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[1]
if str(REPO_ROOT) not in sys.path:
    sys.path.insert(0, str(REPO_ROOT))

from utils.orchestrator.ingest_paper import ingest_paper_and_code


def main():
    input_pdf = REPO_ROOT / "tests" / "Manuscript.pdf"
    input_fortran = REPO_ROOT / "tests" / "benchmark.f90"
    output_dir = REPO_ROOT / "tests" / "ingest_results"

    print(f"PDF:     {input_pdf}")
    print(f"Fortran: {input_fortran}")
    print(f"Output:  {output_dir}")

    result = ingest_paper_and_code(
        pdf_path=input_pdf,
        fortran_path=input_fortran,
        output_dir=output_dir,
    )

    print("\n── Produced Artefacts ──")
    for key, path in result.items():
        exists = Path(path).exists()
        status = "✅" if exists else "❌"
        print(f"  {status} {key}: {path}")


if __name__ == "__main__":
    main()
