# syntax=docker/dockerfile:1.7

# ── Stage 1: Build frontend ───────────────────────────────────────────────
FROM node:20-slim AS frontend-build

WORKDIR /frontend
COPY frontend/package.json frontend/package-lock.json* ./
RUN npm install
COPY frontend/ ./
RUN npm run build

# ── Stage 2: Python backend ──────────────────────────────────────────────
FROM python:3.10-slim

# System deps
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

# Copy backend code
COPY app.py ./

# Copy built frontend
COPY --from=frontend-build /frontend/dist ./frontend/dist

# The project source (utils/, etc.) is mounted as a volume at /app
# DB and data dirs are also volumes.

EXPOSE 5000

CMD ["gunicorn", "--bind", "0.0.0.0:5000", "--timeout", "600", "--workers", "1", "--threads", "4", "app:app"]
