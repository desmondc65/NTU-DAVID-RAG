#!/usr/bin/env bash
# Bring up the whole RAG stack on a SINGLE GPU.
#
# Same stack as ./up.sh, but layers docker-compose.one-gpu.yml on top so the
# embedder (google/embeddinggemma-300m), reranker, MinerU and the LLM
# (gemma3:12b int4 via an in-stack Ollama) all share one card.
#
#   GPU=0 ./up.one-gpu.sh --build      # first run: build images + pull LLM
#   GPU=0 ./up.one-gpu.sh -d           # detached
#
# Pick the card with GPU=<index> (default 0). See README.one-gpu.md for the
# HF_TOKEN requirement and the mandatory ../db wipe (dimension change).
set -euo pipefail

# Run from this script's own directory so the compose files and log.txt
# resolve regardless of CWD.
cd "$(dirname "$0")"

# Selected physical GPU, exported so docker compose can interpolate ${GPU}
# in docker-compose.one-gpu.yml.
export GPU="${GPU:-0}"

# Truncate the log so each `up` starts clean (matches ./up.sh).
: > log.txt

echo "Single-GPU mode → physical GPU ${GPU} (embeddinggemma-300m + reranker + gemma3:12b-int4 + MinerU)" | tee -a log.txt

# `"$@"` forwards extra flags (e.g. --build, -d). 2>&1 merges stderr so tee
# captures both streams to the terminal and log.txt.
docker compose \
  -f docker-compose.yml \
  -f docker-compose.one-gpu.yml \
  up "$@" 2>&1 | tee -a log.txt
