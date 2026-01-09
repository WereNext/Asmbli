#!/usr/bin/env python3
"""
Asmbli DSPy Backend - Main Entry Point

Run with:
    python main.py

Or with uvicorn directly:
    uvicorn src.api.server:app --reload --host 0.0.0.0 --port 8000
"""

import uvicorn
from dotenv import load_dotenv

# Load environment variables
load_dotenv()

from src.config import settings
from src.api.server import app


def main():
    """Run the server"""
    print("=" * 60)
    print("[*] Asmbli DSPy Backend")
    print("=" * 60)
    print(f"[>] Host: {settings.host}")
    print(f"[>] Port: {settings.port}")
    print(f"[>] Default Model: {settings.default_model}")
    print(f"[>] Debug: {settings.debug}")
    print("=" * 60)

    # Check if we have any API keys for LLM features
    has_llm = settings.openai_api_key or settings.anthropic_api_key

    # Validate config - allow graph-only mode without API keys
    valid, messages = settings.validate_config(require_llm=has_llm)
    if not valid:
        print("[!] Configuration errors:")
        for msg in messages:
            print(f"   - {msg}")
        print("\n[i] Please check your .env file")
        return

    if messages:  # Warnings
        print("[!] Configuration warnings:")
        for msg in messages:
            print(f"   - {msg}")

    print("[+] Configuration valid")
    print(f"[i] Available models: {settings.get_available_models()}")
    print("=" * 60)
    print(f"\n[>] API docs available at: http://{settings.host}:{settings.port}/docs")
    print(f"[>] Health check at: http://{settings.host}:{settings.port}/health\n")

    uvicorn.run(
        "src.api.server:app",
        host=settings.host,
        port=settings.port,
        reload=settings.debug,
        log_level="debug" if settings.debug else "info",
    )


if __name__ == "__main__":
    main()
