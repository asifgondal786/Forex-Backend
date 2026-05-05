"""
DeepSeek client (OpenAI-compatible API).
Uses DEEPSEEK_API_KEY from .env.

Provides ALL interfaces needed by existing Tajir services:
- Function API:  ask_deepseek(), chat_completion(), chat_completion_json()
- Class API:     DeepSeekClient (with .available, .generate_json(), .chat(), etc.)
- Health:        deepseek_health(), health_check()
"""
import os
import json
import logging
from typing import Any, Optional
from openai import AsyncOpenAI
from tenacity import retry, stop_after_attempt, wait_exponential

from pathlib import Path
from dotenv import load_dotenv
load_dotenv(dotenv_path=Path(__file__).resolve().parents[2] / ".env", override=True)

logger = logging.getLogger(__name__)

_DEEPSEEK_KEY = os.getenv("DEEPSEEK_API_KEY", "")
_DEEPSEEK_URL = os.getenv("DEEPSEEK_BASE_URL", "https://api.deepseek.com/v1")
_DEEPSEEK_MODEL = os.getenv("DEEPSEEK_MODEL", "deepseek-chat")

_client: Optional[AsyncOpenAI] = None


def _get_client() -> AsyncOpenAI:
    global _client
    if _client is None:
        _client = AsyncOpenAI(api_key=_DEEPSEEK_KEY, base_url=_DEEPSEEK_URL)
        logger.info("DeepSeek client initialised | model=%s", _DEEPSEEK_MODEL)
    return _client


# â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
# CORE FUNCTION API (used by ai_router.py)
# â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•

@retry(stop=stop_after_attempt(3), wait=wait_exponential(min=2, max=10), reraise=True)
async def ask_deepseek(
    prompt: str,
    *,
    system: Optional[str] = None,
    max_tokens: int = 1024,
    temperature: float = 0.7,
) -> dict:
    client = _get_client()
    messages = []
    if system:
        messages.append({"role": "system", "content": system})
    messages.append({"role": "user", "content": prompt})

    try:
        response = await client.chat.completions.create(
            model=_DEEPSEEK_MODEL,
            messages=messages,
            max_tokens=max_tokens,
            temperature=temperature,
        )
        return {
            "provider": "deepseek",
            "model": _DEEPSEEK_MODEL,
            "content": response.choices[0].message.content,
            "usage": {
                "input_tokens": response.usage.prompt_tokens,
                "output_tokens": response.usage.completion_tokens,
            },
            "stop_reason": response.choices[0].finish_reason,
        }
    except Exception as exc:
        logger.error("DeepSeek generation failed: %s", exc)
        raise


async def deepseek_health() -> bool:
    try:
        res = await ask_deepseek("Reply with only OK", max_tokens=10)
        return "ok" in res["content"].lower()
    except Exception:
        return False


# Alias for backward compat
async def health_check() -> bool:
    return await deepseek_health()


# â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
# LEGACY FUNCTION API
# Used by: ai_analysis_service.py, ai_proxy routes, etc.
#   from ..ai.deepseek_client import chat_completion_json, chat_completion
# â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•

async def chat_completion(
    prompt: str,
    *,
    system_prompt: Optional[str] = None,
    model_name: str = "",
    max_tokens: int = 1024,
    temperature: float = 0.7,
) -> str:
    """Return just the text content (simple string)."""
    result = await ask_deepseek(
        prompt,
        system=system_prompt,
        max_tokens=max_tokens,
        temperature=temperature,
    )
    return result["content"]


async def chat_completion_json(
    prompt: str,
    *,
    system_prompt: Optional[str] = None,
    model_name: str = "",
    max_tokens: int = 1024,
    temperature: float = 0.3,
) -> dict:
    """Return parsed JSON from DeepSeek response."""
    raw = await chat_completion(
        prompt,
        system_prompt=system_prompt,
        model_name=model_name,
        max_tokens=max_tokens,
        temperature=temperature,
    )

    # Try to extract JSON from response
    try:
        if "```json" in raw:
            raw = raw.split("```json")[1].split("```")[0]
        elif "```" in raw:
            raw = raw.split("```")[1].split("```")[0]
        return json.loads(raw.strip())
    except (json.JSONDecodeError, IndexError):
        logger.warning("Failed to parse JSON from DeepSeek response: %s", raw[:200])
        return {"raw_response": raw, "parse_error": True}


# â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
# CLASS API
# Used by: signal_service.py, main.py, etc.
#   from app.ai.deepseek_client import DeepSeekClient
# â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•

class DeepSeekClient:
    """
    Class wrapper for backward compatibility.
    Used by signal_service.py and imported in main.py
    """

    def __init__(self):
        self.model = _DEEPSEEK_MODEL
        self._available = bool(_DEEPSEEK_KEY)
        logger.info(
            "DeepSeekClient instance created | model=%s available=%s",
            self.model, self._available,
        )

    @property
    def available(self) -> bool:
        """Check if DeepSeek API key is configured."""
        return self._available

    async def chat(
        self,
        prompt: str,
        system_prompt: Optional[str] = None,
        max_tokens: int = 1024,
        temperature: float = 0.7,
    ) -> str:
        """Send chat and return content string."""
        return await chat_completion(
            prompt,
            system_prompt=system_prompt,
            max_tokens=max_tokens,
            temperature=temperature,
        )

    async def analyze(
        self,
        prompt: str,
        system_prompt: Optional[str] = None,
        max_tokens: int = 1024,
        temperature: float = 0.3,
    ) -> str:
        return await self.chat(
            prompt,
            system_prompt=system_prompt,
            max_tokens=max_tokens,
            temperature=temperature,
        )

    async def generate_json(
        self,
        prompt: str,
        *,
        model_name: str = "",
        system_prompt: Optional[str] = None,
        max_tokens: int = 1024,
        temperature: float = 0.3,
    ) -> dict:
        """Generate and parse JSON response. Used by signal_service.py."""
        return await chat_completion_json(
            prompt,
            system_prompt=system_prompt,
            model_name=model_name or self.model,
            max_tokens=max_tokens,
            temperature=temperature,
        )

    async def generate_signal_analysis(
        self,
        pair: str,
        price: float,
        headlines: Optional[list] = None,
        indicators: Optional[dict] = None,
    ) -> str:
        system = (
            "You are an expert forex analyst for Tajir trading app. "
            "Provide concise, actionable analysis with confidence scores."
        )
        parts = [f"Analyze {pair} at price {price}."]
        if headlines:
            parts.append("Recent news: " + "; ".join(headlines[:5]))
        if indicators:
            parts.append(f"Technical indicators: {indicators}")
        parts.append(
            "Respond with: direction (buy/sell/hold), confidence (0-100), "
            "key levels, and brief reasoning."
        )
        return await self.chat("\n".join(parts), system_prompt=system, temperature=0.3)

    async def health_check(self) -> bool:
        return await deepseek_health()

