#!/bin/bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
DATA_DIR="/home3/davidlcs/Econ-Rag/NTU-DAVID-RAG/data"
MINERU_PY="${SCRIPT_DIR}/mineru.py"
BACKEND="${MINERU_BACKEND:-hybrid-auto-engine}"
METHOD="${MINERU_METHOD:-auto}"

if command -v conda >/dev/null 2>&1; then
    eval "$(conda shell.bash hook)"
elif [ -f "${HOME}/miniconda3/etc/profile.d/conda.sh" ]; then
    # shellcheck disable=SC1091
    source "${HOME}/miniconda3/etc/profile.d/conda.sh"
elif [ -f "${HOME}/anaconda3/etc/profile.d/conda.sh" ]; then
    # shellcheck disable=SC1091
    source "${HOME}/anaconda3/etc/profile.d/conda.sh"
else
    echo "Conda not found. Please install conda or add it to PATH." >&2
    exit 1
fi

conda activate mineru
export CUDA_VISIBLE_DEVICES=2
export MINERU_DEVICE_MODE="cuda:0"

echo "Starting MinerU extraction..."

find "${DATA_DIR}" -type f -path "*/source/Manuscript.pdf" | while IFS= read -r pdf_path; do
    paper_dir="$(dirname "$(dirname "$pdf_path")")"
    output_dir="${paper_dir}/manuscript_parsed_mineru"

    mkdir -p "${output_dir}"
    echo "Processing: ${pdf_path}"
    python3 "${MINERU_PY}" -i "${pdf_path}" -o "${output_dir}" -b "${BACKEND}" -m "${METHOD}"
done

echo "Done. Outputs saved under manuscript_parsed_mineru folders."
