import argparse
import os
import shutil
import subprocess
from pathlib import Path

try:
    from dotenv import load_dotenv

    load_dotenv()
except Exception:
    # Keep the launcher usable even when python-dotenv is not installed.
    pass


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Run local llama.cpp OpenAI-compatible server without Docker."
    )
    parser.add_argument(
        "--llama-server-bin",
        default=os.getenv("LLAMA_SERVER_BIN", "llama-server"),
        help="Path to llama-server executable.",
    )
    parser.add_argument(
        "--model-dir",
        default=os.getenv("MODEL_DIR", ""),
        help="Directory containing GGUF model file.",
    )
    parser.add_argument(
        "--model-file",
        default=os.getenv("MODEL_FILE", ""),
        help="GGUF model filename under model-dir.",
    )
    parser.add_argument(
        "--model-alias",
        default=os.getenv("MODEL_ALIAS", "qwen3-next-80b-instruct-q8_0"),
        help="Model alias exposed by OpenAI-compatible endpoint.",
    )
    parser.add_argument(
        "--host",
        default=os.getenv("LOCAL_LLM_HOST", "0.0.0.0"),
        help="Bind host.",
    )
    parser.add_argument(
        "--port",
        type=int,
        default=int(os.getenv("SERVICE_PORT", "8000")),
        help="Bind port.",
    )
    parser.add_argument(
        "--gpus",
        default=os.getenv("LOCAL_LLM_GPUS", "0,1"),
        help="CUDA_VISIBLE_DEVICES value, for example 0,1.",
    )
    parser.add_argument(
        "--api-key",
        default=os.getenv("LOCAL_LLM_API_KEY", "local-dev-key"),
        help="API key checked by llama.cpp server.",
    )
    parser.add_argument(
        "--tensor-split",
        default=os.getenv("TENSOR_SPLIT", "1,1"),
        help="Tensor split across visible GPUs.",
    )
    parser.add_argument(
        "--ctx-size",
        type=int,
        default=int(os.getenv("CTX_SIZE", "8192")),
        help="Context size.",
    )
    parser.add_argument(
        "--batch-size",
        type=int,
        default=int(os.getenv("BATCH_SIZE", "1024")),
        help="Batch size.",
    )
    parser.add_argument(
        "--ubatch-size",
        type=int,
        default=int(os.getenv("UBATCH_SIZE", "512")),
        help="Micro batch size.",
    )
    parser.add_argument(
        "--threads",
        type=int,
        default=int(os.getenv("THREADS", "16")),
        help="CPU threads.",
    )
    parser.add_argument(
        "--parallel",
        type=int,
        default=int(os.getenv("PARALLEL", "4")),
        help="Parallel request slots.",
    )
    return parser.parse_args()


def resolve_model_path(model_dir: str, model_file: str) -> Path:
    if not model_dir:
        raise ValueError("MODEL_DIR is empty. Set --model-dir or MODEL_DIR in .env.")
    if not model_file:
        raise ValueError("MODEL_FILE is empty. Set --model-file or MODEL_FILE in .env.")

    model_path = Path(model_dir).expanduser().resolve() / model_file
    if not model_path.exists():
        raise FileNotFoundError(f"Model file not found: {model_path}")
    return model_path


def main() -> None:
    args = parse_args()

    bin_path = shutil.which(args.llama_server_bin) or args.llama_server_bin
    if not Path(bin_path).exists() and shutil.which(args.llama_server_bin) is None:
        raise FileNotFoundError(
            f"llama-server executable not found: {args.llama_server_bin}. "
            "Install llama.cpp and ensure llama-server is in PATH, "
            "or set LLAMA_SERVER_BIN."
        )

    model_path = resolve_model_path(args.model_dir, args.model_file)

    env = os.environ.copy()
    env["CUDA_VISIBLE_DEVICES"] = args.gpus
    env["LLAMA_API_KEY"] = args.api_key

    cmd = [
        args.llama_server_bin,
        "--host",
        args.host,
        "--port",
        str(args.port),
        "--model",
        str(model_path),
        "--alias",
        args.model_alias,
        "--n-gpu-layers",
        "999",
        "--tensor-split",
        args.tensor_split,
        "--ctx-size",
        str(args.ctx_size),
        "--batch-size",
        str(args.batch_size),
        "--ubatch-size",
        str(args.ubatch_size),
        "--threads",
        str(args.threads),
        "--parallel",
        str(args.parallel),
        "--flash-attn",
        "--jinja",
    ]

    print("Starting local llama-server without Docker")
    print(f"Model path: {model_path}")
    print(f"Visible GPUs: {args.gpus}")
    print(f"OpenAI base URL: http://{args.host}:{args.port}/v1")
    print("Press Ctrl+C to stop")

    subprocess.run(cmd, env=env, check=True)


if __name__ == "__main__":
    main()