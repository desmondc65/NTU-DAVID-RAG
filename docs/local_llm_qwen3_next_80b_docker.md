# Local LLM Service (Qwen3-Next-80B Q8_0)

This guide starts a local OpenAI-compatible LLM endpoint with GPUs 0 and 1.

## 1. Prerequisites

- Docker Engine + Docker Compose v2
- NVIDIA driver installed
- NVIDIA Container Toolkit configured (`nvidia-smi` works in Docker)
- Qwen3-Next-80B Q8_0 GGUF model file on local disk

## 2. Configure

```bash
cd docker/local_llm
cp .env.example .env
```

Edit `.env`:

- `MODEL_DIR`: absolute directory containing your GGUF file
- `MODEL_FILE`: model filename, for example `Qwen3-Next-80B-Instruct-Q8_0.gguf`
- `SERVICE_PORT`: host port, default `8000`

## 3. Start service on GPU 0 and 1

```bash
cd docker/local_llm
docker compose --env-file .env -f docker-compose.qwen3-next-80b.yml up -d
```

Check status:

```bash
docker compose -f docker-compose.qwen3-next-80b.yml ps
curl http://localhost:8000/health
```

## 4. Call from another script

The server is OpenAI-compatible and binds to `0.0.0.0`, so other scripts can call:

- Same machine: `http://localhost:8000/v1`
- Other machine in LAN: `http://<server-ip>:8000/v1`

Example Python call:

```python
from utils.llm_clients.local_llm import LocalLLMClient

client = LocalLLMClient(
    model_name="qwen3-next-80b-instruct-q8_0",
    base_url="http://<server-ip>:8000/v1",
    api_key="local-dev-key",
)

resp = client.generate_response(
    user_prompt="Summarize the difference between OLS and IV in 3 bullets.",
    response_mime_type="text/plain",
)
print(resp)
```

If your host firewall is enabled, allow TCP `8000`.

## 5. No Docker option (direct local run)

Use this when you want to run locally without Docker.

### Terminal 1: start server

```bash
cd /home3/davidlcs/Econ-Rag/NTU-DAVID-RAG
python -m utils.llm_clients.run_local_llm_server \
    --model-dir /absolute/path/to/your/gguf/models \
    --model-file Qwen3-Next-80B-Instruct-Q8_0.gguf \
    --gpus 0,1 \
    --host 0.0.0.0 \
    --port 8000
```

### Terminal 2: call the service

Health check:

```bash
curl http://localhost:8000/health
```

Quick OpenAI-compatible chat call:

```bash
curl http://localhost:8000/v1/chat/completions \
    -H "Content-Type: application/json" \
    -H "Authorization: Bearer local-dev-key" \
    -d '{
        "model": "qwen3-next-80b-instruct-q8_0",
        "messages": [{"role": "user", "content": "Say hello in one line."}],
        "temperature": 0.2
    }'
```

Python script usage from another terminal:

```python
from utils.llm_clients.local_llm import LocalLLMClient

client = LocalLLMClient(
        model_name="qwen3-next-80b-instruct-q8_0",
        base_url="http://localhost:8000/v1",
        api_key="local-dev-key",
)

resp = client.generate_response(
        user_prompt="Summarize OLS vs IV in 3 bullets.",
        response_mime_type="text/plain",
)
print(resp)
```

## 6. Stop service

```bash
cd docker/local_llm
docker compose -f docker-compose.qwen3-next-80b.yml down
```
