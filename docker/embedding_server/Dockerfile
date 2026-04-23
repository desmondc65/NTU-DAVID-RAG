# syntax=docker/dockerfile:1.7
FROM python:3.10-slim

RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential \
    git \
    libglib2.0-0 \
    libgl1 \
    libsm6 \
    libxext6 \
    libxrender1 \
    libxcb1 \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

COPY requirements.txt ./
RUN --mount=type=cache,target=/root/.cache/pip \
    pip install --upgrade pip && \
    pip install --index-url https://download.pytorch.org/whl/cu121 \
        torch torchvision torchaudio && \
    pip install -r requirements.txt

# server.py imports utils.s2_embedding.embedder to reuse prefix logic;
# utils/ is mounted read-only at runtime.
COPY server.py ./

EXPOSE 8080

# Single worker — the model occupies one GPU slot and is already
# thread-safe behind app-level locks. We intentionally DO NOT use
# --preload: loading CUDA weights in the master and then forking
# workers is forbidden by PyTorch ("Cannot re-initialize CUDA in
# forked subprocess"). Letting the worker load on its own avoids it.
# Model load therefore happens after fork — expect a few-minute warm-
# up before /health reports ready. The healthcheck's start_period in
# docker-compose covers this.
CMD ["gunicorn", "--bind", "0.0.0.0:8080", "--timeout", "1200", "--workers", "1", "--threads", "8", "server:app"]
