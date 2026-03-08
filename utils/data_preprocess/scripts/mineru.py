#!/usr/bin/env python3

import argparse
import sys
from pathlib import Path


SCRIPT_DIR = Path(__file__).resolve().parent
MINERU_DIR = SCRIPT_DIR.parent / "MinerU"
if str(MINERU_DIR) not in sys.path:
    sys.path.insert(0, str(MINERU_DIR))

from mineru.cli.common import do_parse, read_fn


def _parse_subdir(backend: str, method: str) -> str:
    if backend == "pipeline":
        return method
    if backend.startswith("hybrid-"):
        return f"hybrid_{method}"
    if backend.startswith("vlm-"):
        return "vlm"
    return method


def main() -> None:
    parser = argparse.ArgumentParser(description="Parse one PDF with MinerU.")
    parser.add_argument("-i", "--input", required=True, help="Input PDF path")
    parser.add_argument("-o", "--output", required=True, help="Output directory")
    parser.add_argument("-b", "--backend", default="hybrid-auto-engine")
    parser.add_argument("-m", "--method", default="auto")
    parser.add_argument("-l", "--lang", default="ch")
    parser.add_argument("-u", "--url", default=None)
    parser.add_argument("-s", "--start", type=int, default=0)
    parser.add_argument("-e", "--end", type=int, default=None)
    args = parser.parse_args()

    input_path = Path(args.input)
    output_dir = Path(args.output)
    output_dir.mkdir(parents=True, exist_ok=True)

    do_parse(
        output_dir=str(output_dir),
        pdf_file_names=[input_path.stem],
        pdf_bytes_list=[read_fn(input_path)],
        p_lang_list=[args.lang],
        backend=args.backend,
        parse_method=args.method,
        server_url=args.url,
        start_page_id=args.start,
        end_page_id=args.end,
    )
    expected_md = output_dir / input_path.stem / _parse_subdir(args.backend, args.method) / f"{input_path.stem}.md"
    if not expected_md.exists():
        raise RuntimeError(f"MinerU did not produce expected output: {expected_md}")


if __name__ == "__main__":
    main()
