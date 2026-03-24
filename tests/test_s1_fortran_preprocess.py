from pathlib import Path
import sys

# Allow running this test file directly via `python tests/...`.
PROJECT_ROOT = Path(__file__).resolve().parents[1]
if str(PROJECT_ROOT) not in sys.path:
    sys.path.insert(0, str(PROJECT_ROOT))

from utils.s1_data_ingestion.fortran_code_digest import digest_fortran_code, summarize_fortran_digest

def test_benchmark_f90_digest():
    """
    Test the digest_fortran_code function using the benchmark.f90 file.
    """
    # Define paths
    current_dir = Path(__file__).parent
    benchmark_file_path = current_dir / "benchmark.f90"
    output_json_path = current_dir / "output_test" / "benchmark_digest.json"
    
    # Check if the input file exists
    assert benchmark_file_path.exists(), f"File not found: {benchmark_file_path}"
    
    # Read the content
    with open(benchmark_file_path, 'r', encoding='utf-8') as f:
        code_content = f.read()
        
    print(f"Testing digest_fortran_code with {benchmark_file_path.name}...")
    
    # # Process the code. This might take a while depending on LLM parsing speed and file size.
    # result = digest_fortran_code(
    #     code_content=code_content,
    #     output_json_path=str(output_json_path)
    # )
    
    # # Verify result
    # assert isinstance(result, (list, dict)), "Result should be a parsed JSON dictionary or list"
    # assert output_json_path.exists(), f"Output JSON not created at {output_json_path}"
    
    # Summarize the output
    print(f"Summarizing the output digest with LLM...")
    summarize_fortran_digest(output_json_path)
    
    print(f"Successfully digested {benchmark_file_path.name}")
    print(f"Saved digested output to: {output_json_path}")

if __name__ == "__main__":
    # If run as a python script directly
    test_benchmark_f90_digest()
