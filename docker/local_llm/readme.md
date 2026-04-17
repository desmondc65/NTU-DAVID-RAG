# Local LLM — Gemma4 31B (Ollama)

Runs `gemma4:31b` via Ollama in a GPU-enabled container.

## File
- [docker-compose.gemma4_31b_ollama.yml](docker-compose.gemma4_31b_ollama.yml)

## Requirements
- Docker + `nvidia-container-toolkit`
- NVIDIA GPU with CUDA (uses device index `2`)

## Usage

```bash
docker compose -f docker-compose.gemma4_31b_ollama.yml up -d
```

On first start the container will:
1. Launch `ollama serve`
2. Pull `gemma4:31b`
3. Warm up the model with a dummy prompt

API is exposed at `http://localhost:11434`.

## Notes
- GPU: pinned to device `2` via `NVIDIA_VISIBLE_DEVICES` / `CUDA_VISIBLE_DEVICES`.
- `OLLAMA_KEEP_ALIVE=-1` keeps the model resident in VRAM.
- Model data persists in the `ollama_storage` volume.

## Stop

```bash
docker compose -f docker-compose.gemma4_31b_ollama.yml down
```
