"""Shared Gemini client wrapper used across backend AI modules."""

from __future__ import annotations

import json
import logging
import os
from typing import Any, Optional

try:
    import google.generativeai as genai
    GENAI_AVAILABLE = True
except ImportError:
    genai = None
    GENAI_AVAILABLE = False

logger = logging.getLogger(__name__)


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
    """Gemini client using google-generativeai SDK."""

    def __init__(self, api_key: Optional[str] = None):
        key = (api_key or os.getenv("GEMINI_API_KEY") or "").strip()
        self.api_key = key
        self._available = bool(key) and GENAI_AVAILABLE
        if self._available:
            genai.configure(api_key=key)

    @property
    def available(self) -> bool:
        # Lazy re-check in case key was missing at import time
        if not self._available:
            key = os.getenv("GEMINI_API_KEY", "").strip()
            if key and GENAI_AVAILABLE:
                self.api_key = key
                self._available = True
                genai.configure(api_key=key)
        return self._available

    def generate_text(self, *, model_name: str, prompt: str) -> str:
        if not self.available:
            logger.warning("GeminiClient: not available (key missing or package not installed)")
            return ""
        try:
            model = genai.GenerativeModel(model_name)
            response = model.generate_content(prompt)
            return (getattr(response, "text", "") or "").strip()
        except Exception as e:
            logger.error("GeminiClient.generate_text failed: %s", e, exc_info=True)
            return ""

    def generate_json(
        self,
        *,
        model_name: str,
        prompt: str,
        fallback: Optional[dict[str, Any]] = None,
    ) -> dict[str, Any]:
        default_value = fallback or {}
        try:
            raw_text = self.generate_text(model_name=model_name, prompt=prompt)
            json_text = _extract_json_block(raw_text)
            if not json_text:
                logger.warning("GeminiClient: empty response from model")
                return default_value
            parsed = json.loads(json_text)
            if isinstance(parsed, dict):
                return parsed
            return default_value
        except Exception as e:
            logger.error("GeminiClient.generate_json failed: %s", e, exc_info=True)
            return default_value


gemini_client = GeminiClient()
