import os
from io import BytesIO
import time
from copy import deepcopy
from typing import Any

import requests
import torch
from fastapi import FastAPI, Header, HTTPException
from pydantic import BaseModel, Field
from PIL import Image
from transformers import pipeline

MODEL_ID = os.getenv("GEMMA_MODEL_ID", "google/gemma-4-31b-it")
MODEL_ALIAS = os.getenv("GEMMA_MODEL_ALIAS", "gemma4-31b-it")
DTYPE_ENV = os.getenv("GEMMA_DTYPE", "auto")
API_KEY = os.getenv("LOCAL_LLM_API_KEY", "")
DEFAULT_MAX_NEW_TOKENS = int(os.getenv("GEMMA_MAX_NEW_TOKENS", "512"))


def resolve_dtype(value: str) -> Any:
    if value == "auto":
        return "auto"
    mapping = {
        "float16": torch.float16,
        "bfloat16": torch.bfloat16,
        "float32": torch.float32,
    }
    return mapping.get(value, "auto")


pipe = pipeline(
    task="any-to-any",
    model=MODEL_ID,
    device_map="auto",
    dtype=resolve_dtype(DTYPE_ENV),
)

app = FastAPI(title="Gemma OpenAI-Compatible Server")


class ChatMessage(BaseModel):
    role: str
    content: Any


class ChatCompletionRequest(BaseModel):
    model: str | None = None
    messages: list[ChatMessage]
    max_tokens: int | None = Field(default=None, ge=1)
    temperature: float | None = None


def auth_guard(authorization: str | None) -> None:
    if not API_KEY:
        return
    if not authorization or not authorization.startswith("Bearer "):
        raise HTTPException(status_code=401, detail="Missing bearer token")
    token = authorization.removeprefix("Bearer ").strip()
    if token != API_KEY:
        raise HTTPException(status_code=401, detail="Invalid API key")


def load_image_from_url(url: str) -> Image.Image:
    resp = requests.get(url, timeout=20)
    resp.raise_for_status()
    return Image.open(BytesIO(resp.content)).convert("RGB")


def normalize_content(content: Any) -> list[dict[str, Any]]:
    if isinstance(content, str):
        return [{"type": "text", "text": content}]
    if isinstance(content, list):
        normalized: list[dict[str, Any]] = []
        for entry in content:
            if not isinstance(entry, dict):
                continue
            ctype = entry.get("type")
            if ctype == "text":
                normalized.append({"type": "text", "text": entry.get("text", "")})
            elif ctype == "image":
                url = entry.get("url")
                if isinstance(url, str) and url:
                    normalized.append({"type": "image", "image": load_image_from_url(url)})
                elif isinstance(entry.get("image_url"), dict):
                    img_url = entry["image_url"].get("url", "")
                    if img_url:
                        normalized.append({"type": "image", "image": load_image_from_url(img_url)})
        return normalized
    return [{"type": "text", "text": str(content)}]


def normalize_messages(messages: list[ChatMessage]) -> list[dict[str, Any]]:
    return [{"role": m.role, "content": normalize_content(m.content)} for m in messages]


@app.get("/health")
def health() -> dict[str, str]:
    return {"status": "ok", "model": MODEL_ID}


@app.get("/v1/models")
def list_models(authorization: str | None = Header(default=None)) -> dict[str, Any]:
    auth_guard(authorization)
    return {
        "object": "list",
        "data": [
            {
                "id": MODEL_ALIAS,
                "object": "model",
                "owned_by": "google",
            }
        ],
    }


@app.post("/v1/chat/completions")
def chat_completions(
    request: ChatCompletionRequest,
    authorization: str | None = Header(default=None),
) -> dict[str, Any]:
    auth_guard(authorization)

    max_new_tokens = request.max_tokens or DEFAULT_MAX_NEW_TOKENS
    messages = normalize_messages(request.messages)

    generation_config = deepcopy(pipe.model.generation_config)
    generation_config.max_new_tokens = max_new_tokens
    generation_config.max_length = None

    output = pipe(
        text=messages,
        return_full_text=False,
        generate_kwargs={"generation_config": generation_config},
    )

    if not output or not isinstance(output, list):
        raise HTTPException(status_code=500, detail="Empty model output")

    generated_text = output[0].get("generated_text", "")
    if isinstance(generated_text, list):
        joined = []
        for item in generated_text:
            if isinstance(item, dict) and item.get("type") == "text":
                joined.append(item.get("text", ""))
        generated_text = "\n".join([s for s in joined if s])

    model_name = request.model or MODEL_ALIAS

    return {
        "id": "chatcmpl-local-gemma",
        "object": "chat.completion",
        "created": int(time.time()),
        "model": model_name,
        "choices": [
            {
                "index": 0,
                "message": {"role": "assistant", "content": generated_text},
                "finish_reason": "stop",
            }
        ],
    }
