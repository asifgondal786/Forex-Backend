"""Shared Gemini client wrapper used across backend AI modules."""

from __future__ import annotations

import json
import os
from typing import Any, Optional

try:
    from google import genai
    from google.genai import types as genai_types
except ImportError:
    genai = None
    genai_types = None


def _extract_json_block(raw_text: str) -> str:
    text = (raw_text or "").strip()
    if not text:
        return ""

    if text.startswith("```"):
        lines = text.splitlines()
        if lines:
            lines = lines[1:]
        if lines and lines[-1].strip() == "```":
            lines = lines[:-1]
        text = "\n".join(lines).strip()
        if text.lower().startswith("json"):
            text = text[4:].strip()
    return text


class GeminiClient:
    """Minimal Gemini client with guarded availability and JSON parsing."""

    def __init__(self, api_key: Optional[str] = None):
        configured_key = (api_key or os.getenv("GEMINI_API_KEY") or "").strip()
        self.api_key = configured_key
        self._available = bool(configured_key) and genai is not None
        if self._available:
            self._client = genai.Client(api_key=configured_key)
        else:
            self._client = None

    @property
    def available(self) -> bool:
        return self._available

    def generate_text(self, *, model_name: str, prompt: str) -> str:
        # Re-read key lazily in case it was not set at import time
        if not self._available:
            key = os.getenv("GEMINI_API_KEY", "").strip()
            if key and genai is not None:
                self.api_key = key
                self._client = genai.Client(api_key=key)
                self._available = True
        if not self._available:
            return ""
        response = self._client.models.generate_content(
            model=model_name,
            contents=prompt,
        )
        return (getattr(response, "text", "") or "").strip()

    def generate_json(
        self,
        *,
        model_name: str,
        prompt: str,
        fallback: Optional[dict[str, Any]] = None,
    ) -> dict[str, Any]:
        default_value = fallback or {}
        if not self.available:
            return default_value
        try:
            raw_text = self.generate_text(model_name=model_name, prompt=prompt)
            json_text = _extract_json_block(raw_text)
            if not json_text:
                return default_value
            parsed = json.loads(json_text)
            if isinstance(parsed, dict):
                return parsed
            return default_value
        except Exception as e:
            import logging
            logging.getLogger(__name__).error("GeminiClient.generate_json failed: %s", e, exc_info=True)
            return default_value


def get_gemini_client() -> GeminiClient:
    return GeminiClient()

gemini_client = GeminiClient()



