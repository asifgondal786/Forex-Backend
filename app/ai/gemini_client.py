"""Compatibility shim: existing Gemini imports now use DeepSeek underneath."""

from __future__ import annotations

import os
from typing import Optional

from .deepseek_client import DeepSeekClient


class GeminiClient(DeepSeekClient):
    """Backward-compatible class name for older callers."""

    def __init__(self, api_key: Optional[str] = None):
        super().__init__(
            api_key=api_key or os.getenv("DEEPSEEK_API_KEY") or os.getenv("GEMINI_API_KEY"),
            model=os.getenv("DEEPSEEK_MODEL") or "deepseek-chat",
        )


gemini_client = GeminiClient()
