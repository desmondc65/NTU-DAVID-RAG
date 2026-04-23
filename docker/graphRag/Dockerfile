# syntax=docker/dockerfile:1.7

# ── Stage 1: Build frontend ───────────────────────────────────────────────
FROM node:20-slim AS frontend-build

# VITE_BASE_PATH lets the unified proxy host this app under a prefix
# (e.g. '/graph/'). Default '/' keeps the single-container compose working.
ARG VITE_BASE_PATH=/
ENV VITE_BASE_PATH=${VITE_BASE_PATH}

WORKDIR /frontend
COPY frontend/package.json frontend/package-lock.json* ./
RUN npm install
COPY frontend/ ./
RUN npm run build

# ── Stage 2: Python backend ──────────────────────────────────────────────
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

# Install Python dependencies
COPY requirements.txt ./
RUN --mount=type=cache,target=/root/.cache/pip \
        pip install --upgrade pip && \
        pip install --index-url https://download.pytorch.org/whl/cu121 \
            torch torchvision torchaudio && \
    pip install -r requirements.txt

# Copy backend code — utils/ and graphRag/ are mounted as volumes at runtime.
COPY app.py ./

# Copy built frontend
COPY --from=frontend-build /frontend/dist ./frontend/dist

EXPOSE 5000

CMD ["gunicorn", "--bind", "0.0.0.0:5000", "--timeout", "1200", "--workers", "1", "--threads", "4", "app:app"]
