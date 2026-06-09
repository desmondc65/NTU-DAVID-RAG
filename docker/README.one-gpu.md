# Single-GPU mode

Run the entire RAG stack on **one** GPU instead of the default two.

| | Default (2-GPU) | Single-GPU |
|---|---|---|
| Embedder | `Alibaba-NLP/gte-Qwen2-7B-instruct` (3584-dim, ~14 GB) | `google/embeddinggemma-300m` (768-dim, ~0.6 GB) |
| Reranker | `BAAI/bge-reranker-v2-m3` (~2.2 GB) | *same* |
| LLM | `gemma4:31b` — separate `local_llm` stack on its own card | `gemma3:12b-it-qat` (int4, ~8 GB) — in-stack Ollama |
| GPUs used | embedder card + LLM card (+ MinerU card) | **one card for all of it** |

Rough VRAM on the single card: ~0.6 (embedder) + ~2.2 (reranker) + ~8 (LLM) + ~5 (MinerU, only during ingestion) ≈ **16 GB peak**, comfortable on a 24 GB card.

The default setup is **untouched** — this is a compose override you opt into. Plain `./up.sh` still runs the original 2-GPU stack.

---

## One-time setup

### 1. Get a Hugging Face token (the embedder is gated)

`google/embeddinggemma-300m` requires accepting Google's license:

1. Sign in to Hugging Face and open <https://huggingface.co/google/embeddinggemma-300m> — click **Agree / Access repository**.
2. Create a **read** token at <https://huggingface.co/settings/tokens>.
3. Add it to `docker/.env`:
   ```
   HF_TOKEN=hf_xxxxxxxxxxxxxxxxxxxxx
   ```
   (`gemma3:12b` comes from Ollama and needs no token.)

### 2. Re-ingest your papers (no wipe needed)

embeddinggemma emits **768-dim** vectors; the old embedder produced **3584-dim**. A Qdrant collection has a fixed dimension, so the two can't share one — but they **don't have to**. Each embedder writes to its own collections:

| Embedder | Chunk collection | Profile collection |
|---|---|---|
| gte-Qwen2-7B (default) | `rag_embeddings` | `paper_profiles` |
| embeddinggemma-300m | `rag_embeddings__embeddinggemma-300m` | `paper_profiles__embeddinggemma-300m` |

So switching embedders is **non-destructive** — your existing 3584-dim vectors stay intact, and the new model starts with empty collections. **Re-ingest your papers through the UI** while in single-GPU mode to populate them. Switch back to the 2-GPU stack later and the original vectors are queried again, untouched.

> No `rm -rf db/*` required. The mechanism lives in [utils/s2_embedding/collections.py](../utils/s2_embedding/collections.py); the active model comes from rag-web's `EMBEDDING_MODEL` (set automatically by the override).

---

## Run

```bash
cd docker
GPU=0 ./up.one-gpu.sh --build      # first run: builds images, pulls the LLM
```

- `--build` is needed the first time (the embedding image picks up the newer `sentence-transformers`/`transformers` that support embeddinggemma).
- First boot also pulls the ~8 GB `gemma3:12b-it-qat` into the `ollama_storage` volume — the `ollama` container reports healthy only once that finishes, and `rag-web` waits for it. Subsequent boots are fast.
- Detached: `GPU=0 ./up.one-gpu.sh -d`. Logs stream to `docker/log.txt`.

Equivalent without the wrapper:

```bash
GPU=0 docker compose -f docker-compose.yml -f docker-compose.one-gpu.yml up --build
```

The dashboard is on `http://<host>:${UNIFIED_PORT:-3006}/` as usual. Then re-ingest your papers through the UI so the collections are rebuilt at 768-dim.

---

## Knobs

Set in `docker/.env` (see [.env.one-gpu.example](.env.one-gpu.example)) or inline before the command:

| Var | Default | Meaning |
|---|---|---|
| `GPU` | `0` | Physical card index for the whole stack |
| `ONE_GPU_EMBEDDING_MODEL` | `google/embeddinggemma-300m` | Embedder id |
| `ONE_GPU_LLM_MODEL` | `gemma3:12b-it-qat` | Ollama LLM tag (e.g. `gemma3:12b` for plain q4_0) |
| `HF_TOKEN` | — | HF read token for the gated embedder (**required**) |

Each distinct `ONE_GPU_EMBEDDING_MODEL` gets its own `rag_embeddings__<tag>` / `paper_profiles__<tag>` collections — no wipe when you change it, but re-ingest under the new model to populate its (initially empty) collections.

---

## Switching back to 2-GPU

```bash
cd docker
docker compose -f docker-compose.yml -f docker-compose.one-gpu.yml down   # stop single-GPU
./up.sh                                                                    # original stack
```

No wipe — the 2-GPU stack reads the original `rag_embeddings` / `paper_profiles` collections, which were never touched. The embeddinggemma collections just sit idle until you next run single-GPU mode.

---

## How it works

- [docker-compose.one-gpu.yml](docker-compose.one-gpu.yml) is a compose **override** layered on the base file. It:
  - sets `EMBEDDING_MODEL` on `embedding-server` to embeddinggemma and passes `HF_TOKEN` through;
  - adds an `ollama` service on the stack network and points `rag-web`'s `LOCAL_LLM_BASE_URL` at `http://ollama:11434/v1` (overriding the host-network URL in `RAG/.env`);
  - pins `embedding-server`, `rag-web` (MinerU) and `ollama` all to `${GPU}` — selection is by physical index because the containers run `privileged`, so the deploy reservations are kept aligned with `CUDA_VISIBLE_DEVICES`.
- The embeddinggemma retrieval prompts (`task: search result | query:` / `title: none | text:`) are applied server-side in [utils/s2_embedding/embedder.py](../utils/s2_embedding/embedder.py), matching how the other model families are handled.
