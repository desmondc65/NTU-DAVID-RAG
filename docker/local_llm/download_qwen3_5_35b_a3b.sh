#!/bin/bash
# Description: Downloads Qwen3.5-35B-A3B model files from Hugging Face.
# Uses wget for robust, resumable shard download.

set -euo pipefail

MODEL_REPO="Qwen/Qwen3.5-35B-A3B"
MODEL_DIR="/home3/davidlcs/Econ-Rag/Models/Qwen3.5-35B-A3B"
BASE_URL="https://huggingface.co/${MODEL_REPO}/resolve/main"

if ! command -v wget >/dev/null 2>&1; then
  echo "wget not found. Install it first." >&2
  exit 1
fi

mkdir -p "$MODEL_DIR"

echo "Downloading ${MODEL_REPO} into ${MODEL_DIR} ..."

# If HUGGING_FACE_HUB_TOKEN (or HF_TOKEN) is set, include it for authenticated downloads.
HF_TOKEN="${HUGGING_FACE_HUB_TOKEN:-${HF_TOKEN:-}}"
WGET_ARGS=("-c" "--show-progress")
if [[ -n "$HF_TOKEN" ]]; then
  WGET_ARGS+=("--header=Authorization: Bearer $HF_TOKEN")
fi

download_file() {
  local filename="$1"
  wget "${WGET_ARGS[@]}" "${BASE_URL}/${filename}?download=true" -O "${MODEL_DIR}/${filename}"
}

# Core model/config files required by vLLM + transformers loading.
FILES=(
  ".gitattributes"
  "LICENSE"
  "README.md"
  "chat_template.jinja"
  "config.json"
  "generation_config.json"
  "merges.txt"
  "model.safetensors.index.json"
  "preprocessor_config.json"
  "tokenizer.json"
  "tokenizer_config.json"
  "video_preprocessor_config.json"
  "vocab.json"
)

for f in "${FILES[@]}"; do
  echo "Downloading ${f} ..."
  download_file "$f"
done

for i in $(seq -w 1 14); do
  shard="model.safetensors-${i}-of-00014.safetensors"
  echo "Downloading ${shard} ..."
  download_file "$shard"
done

echo "Download complete."
echo "If you hit 401/403, export HUGGING_FACE_HUB_TOKEN first."
