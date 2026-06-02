#!/usr/bin/env bash
# Strict mode: -e exit on error, -u error on unset vars,
# -o pipefail so a failure in `docker compose` (left side of the pipe)
# isn't masked by `tee` succeeding on the right side.
set -euo pipefail

# Run from this script's own directory so `docker compose` finds
# ./docker-compose.yml and `log.txt` lands here regardless of CWD.
cd "$(dirname "$0")"

# Truncate log.txt to zero bytes (`:` is a no-op; `>` does the truncation).
# Runs every invocation, so each `up` starts with a clean log.
: > log.txt

# Start the stack in the foreground. `"$@"` forwards any extra flags
# (e.g. `./up.sh -d`, `./up.sh --build`) straight to docker compose.
# 2>&1 merges stderr into stdout so `tee` captures both streams.
# `tee log.txt` writes the combined output to the file *and* the terminal.
docker compose up "$@" 2>&1 | tee log.txt
