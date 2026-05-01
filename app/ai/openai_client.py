"""
app/ai/openai_client.py      (later on may be converted to claude_client.py)
OpenAI-compatible NLP client for Tajir.
Currently uses OpenAI (ChatGPT). Swap to Claude later by changing:
  - OPENAI_API_KEY  →  CLAUDE_API_KEY
  - base_url        →  https://api.anthropic.com/v1
  - model           →  claude-sonnet-4-20250514
  - header          →  x-api-key instead of Authorization Bearer
"""
from __future__ import annotations

import json
import logging
import os
from typing import Any

import httpx
from tenacity import retry, retry_if_exception_type, stop_after_attempt, wait_exponential

logger = logging.getLogger(__name__)

_RETRYABLE = (
    httpx.ConnectError,
    httpx.ReadError,
    httpx.ReadTimeout,
    httpx.RemoteProtocolError,
)

# ── System prompt for Tajir NLP ──────────────────────────────────────────────
TAJIR_SYSTEM_PROMPT = """You are Tajir's AI trading copilot. Parse user commands about forex trading 
and return ONLY a valid JSON object. No explanation, no markdown, no extra text.

Return this exact structure:
{
  "intent": one of [OPEN_TRADE, CLOSE_TRADE, GET_SIGNAL, GET_NEWS, GET_RISK, GET_PERFORMANCE, SET_ALERT, STOP_ALL, CHAT],
  "direction": "BUY" or "SELL" or null,
  "pair": forex pair like "EUR_USD" or null,
  "risk_pct": decimal risk like 0.01 for 1% or null,
  "entry_price": float or null,
  "stop_loss": float or null,
  "take_profit": float or null,
  "condition": trigger condition string or null,
  "confidence": float 0.0-1.0,
  "requires_confirmation": true or false,
  "response": short human-readable reply to show user
}

Rules:
- Forex pairs use underscore format: EUR_USD, GBP_USD, USD_JPY, AUD_USD, USD_CAD, USD_CHF, NZD_USD
- risk_pct is always a decimal (1% = 0.01, 2% = 0.02)
- OPEN_TRADE and CLOSE_TRADE always require_confirmation = true
- STOP_ALL always requires_confirmation = true  
- confidence > 0.8 if pair and direction are clear, 0.5-0.8 if partially clear, < 0.5 if vague
- CHAT intent means you could not parse a trading action — response should be a helpful suggestion
- Keep response under 100 characters, conversational tone"""


class ClaudeClient:
    """
    OpenAI-compatible client. Named ClaudeClient so the rest of the codebase
    never changes when you swap the underlying model.
    """

    def __init__(self) -> None:
        self.api_key = os.getenv("OPENAI_API_KEY", "").strip()
        self.base_url = "https://api.openai.com/v1"
        self.model = os.getenv("OPENAI_MODEL", "gpt-4o-mini").strip()
        self.timeout = 20.0
        self._client: httpx.AsyncClient | None = None

    @property
    def available(self) -> bool:
        key = os.getenv("OPENAI_API_KEY", "").strip()
        if key:
            self.api_key = key
            return True
        return bool(self.api_key)

    def _headers(self) -> dict[str, str]:
        return {
            "Authorization": f"Bearer {self.api_key}",
            "Content-Type": "application/json",
        }

    async def _get_client(self) -> httpx.AsyncClient:
        if self._client is None or self._client.is_closed:
            self._client = httpx.AsyncClient(timeout=self.timeout)
        return self._client

    @retry(
        retry=retry_if_exception_type(_RETRYABLE),
        wait=wait_exponential(multiplier=1, min=1, max=8),
        stop=stop_after_attempt(3),
        reraise=True,
    )
    async def _post(self, payload: dict[str, Any]) -> dict[str, Any]:
        if not self.available:
            raise RuntimeError("OPENAI_API_KEY is not configured.")
        client = await self._get_client()
        response = await client.post(
            f"{self.base_url}/chat/completions",
            headers=self._headers(),
            json=payload,
        )
        response.raise_for_status()
        return response.json()

    async def parse_trading_command(self, user_text: str) -> dict[str, Any]:
        """
        Send user text to OpenAI with Tajir system prompt.
        Returns parsed structured JSON dict.
        """
        payload = {
            "model": self.model,
            "temperature": 0.1,  # Low temp for consistent structured output
            "max_tokens": 300,
            "response_format": {"type": "json_object"},
            "messages": [
                {"role": "system", "content": TAJIR_SYSTEM_PROMPT},
                {"role": "user", "content": user_text},
            ],
        }
        try:
            data = await self._post(payload)
            choices = data.get("choices", [])
            if not choices:
                return {}
            content = choices[0].get("message", {}).get("content", "")
            parsed = json.loads(content)
            return parsed if isinstance(parsed, dict) else {}
        except json.JSONDecodeError as e:
            logger.error("OpenAI returned invalid JSON: %s", e)
            return {}
        except Exception as e:
            logger.error("OpenAI parse_trading_command failed: %s", e, exc_info=True)
            return {}

    async def health_check(self) -> dict[str, Any]:
        if not self.available:
            return {"status": "unconfigured", "available": False, "model": self.model}
        try:
            payload = {
                "model": self.model,
                "max_tokens": 5,
                "temperature": 0.0,
                "messages": [{"role": "user", "content": "Reply OK"}],
            }
            data = await self._post(payload)
            choices = data.get("choices", [])
            ok = bool(choices and choices[0].get("message", {}).get("content"))
            return {"status": "ok" if ok else "degraded", "available": True, "model": self.model}
        except Exception as e:
            logger.warning("OpenAI health check failed: %s", e)
            return {"status": "degraded", "available": True, "model": self.model, "error": str(e)}

    async def close(self) -> None:
        if self._client and not self._client.is_closed:
            await self._client.aclose()
        self._client = None


# Singleton — import this everywhere
claude_client = ClaudeClient()