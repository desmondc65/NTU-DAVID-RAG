#!/bin/bash
# Description: Downloads Qwen2.5-VL-72B-Instruct GGUF and mmproj files
# Uses wget locally to avoid any python/pip/docker issues.

MODEL_DIR="/home3/davidlcs/Econ-Rag/Models"
BASE_URL="https://huggingface.co/unsloth/Qwen2.5-VL-72B-Instruct-GGUF/resolve/main"

echo "Downloading Qwen2.5-VL-72B-Instruct-Q4_K_M.gguf (approx ~42GB)..."
wget -c --show-progress "$BASE_URL/Qwen2.5-VL-72B-Instruct-Q4_K_M.gguf?download=true" -O "$MODEL_DIR/Qwen2.5-VL-72B-Instruct-Q4_K_M.gguf"

echo "Downloading mmproj-F16.gguf (vision projector, approx ~1.5GB)..."
wget -c --show-progress "$BASE_URL/mmproj-F16.gguf?download=true" -O "$MODEL_DIR/mmproj-F16.gguf"

echo "Download complete! You can now start the docker-compose service."
