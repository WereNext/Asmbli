"""
Configuration management for DSPy backend

API keys are read from environment variables. Set them in your shell:
    export OPENAI_API_KEY="sk-..."
    export ANTHROPIC_API_KEY="sk-ant-..."

Or pass them when running:
    OPENAI_API_KEY="sk-..." python main.py
"""

from __future__ import annotations

import subprocess
from pathlib import Path
from typing import Optional

from pydantic import Field
from pydantic_settings import BaseSettings


def get_keychain_value(service: str, account: str) -> Optional[str]:
    """Try to get a value from macOS Keychain"""
    try:
        result = subprocess.run(
            ["security", "find-generic-password", "-s", service, "-a", account, "-w"],
            capture_output=True,
            text=True,
            timeout=5,
        )
        if result.returncode == 0:
            return result.stdout.strip()
    except Exception:
        pass
    return None


class Settings(BaseSettings):
    """
    Application settings loaded from environment variables.

    Priority order:
    1. Environment variables (OPENAI_API_KEY, ANTHROPIC_API_KEY)
    2. macOS Keychain (if on macOS)
    3. .env file (if exists, NOT recommended for production)
    """

    # API Keys - read from environment
    openai_api_key: Optional[str] = Field(default=None, alias="OPENAI_API_KEY")
    anthropic_api_key: Optional[str] = Field(default=None, alias="ANTHROPIC_API_KEY")

    # Model Configuration - use latest Claude Sonnet 4 by default
    default_model: str = Field(default="anthropic/claude-sonnet-4-20250514", alias="DEFAULT_MODEL")

    # Server Configuration
    host: str = Field(default="0.0.0.0", alias="HOST")
    port: int = Field(default=8000, alias="PORT")
    debug: bool = Field(default=False, alias="DEBUG")

    # Vector Database
    chroma_persist_dir: str = Field(default="./data/chroma", alias="CHROMA_PERSIST_DIR")
    chroma_collection_name: str = Field(default="asmbli_docs", alias="CHROMA_COLLECTION_NAME")

    # Optimization Settings
    max_bootstrapped_demos: int = Field(default=4, alias="MAX_BOOTSTRAPPED_DEMOS")
    max_labeled_demos: int = Field(default=16, alias="MAX_LABELED_DEMOS")

    class Config:
        env_file = ".env"
        env_file_encoding = "utf-8"
        extra = "ignore"

    def __init__(self, **kwargs):
        super().__init__(**kwargs)
        # Try macOS Keychain as fallback if no API keys from environment
        if not self.openai_api_key:
            keychain_key = get_keychain_value("Asmbli", "openai_api_key")
            if keychain_key:
                object.__setattr__(self, "openai_api_key", keychain_key)
        if not self.anthropic_api_key:
            keychain_key = get_keychain_value("Asmbli", "anthropic_api_key")
            if keychain_key:
                object.__setattr__(self, "anthropic_api_key", keychain_key)

    def get_available_models(self) -> list[str]:
        """Return list of available models based on configured API keys"""
        models = []
        if self.openai_api_key:
            models.extend([
                "openai/gpt-4o",
                "openai/gpt-4o-mini",
                "openai/gpt-4.1",
                "openai/o1",
                "openai/o3-mini",
            ])
        if self.anthropic_api_key:
            models.extend([
                "anthropic/claude-sonnet-4-20250514",
                "anthropic/claude-opus-4-20250514",
                "anthropic/claude-3-7-sonnet-20250219",
            ])
        return models

    def validate_config(self, require_llm: bool = True) -> tuple[bool, list[str]]:
        """Validate configuration and return status with any errors

        Args:
            require_llm: If True, require at least one API key. Set False for graph-only mode.
        """
        errors = []
        warnings = []

        if not self.openai_api_key and not self.anthropic_api_key:
            if require_llm:
                errors.append("At least one API key (OPENAI_API_KEY or ANTHROPIC_API_KEY) is required")
            else:
                warnings.append("No API keys configured - LLM features disabled, graph-only mode active")

        # Validate default model matches available keys (only if LLM required)
        if require_llm:
            if self.default_model.startswith("openai/") and not self.openai_api_key:
                errors.append(f"Default model {self.default_model} requires OPENAI_API_KEY")
            if self.default_model.startswith("anthropic/") and not self.anthropic_api_key:
                errors.append(f"Default model {self.default_model} requires ANTHROPIC_API_KEY")

        # Ensure data directory exists
        Path(self.chroma_persist_dir).mkdir(parents=True, exist_ok=True)

        return len(errors) == 0, errors + warnings


# Global settings instance
settings = Settings()
