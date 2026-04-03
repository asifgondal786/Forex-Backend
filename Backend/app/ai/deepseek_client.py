"""Shared DeepSeek client helpers for async and compatibility use."""

from __future__ import annotations

import json
import logging
import os
from typing import Any, AsyncIterator

import httpx
from tenacity import retry, retry_if_exception_type, stop_after_attempt, wait_exponential

logger = logging.getLogger(__name__)

_RETRYABLE_EXCEPTIONS = (
    httpx.ConnectError,
    httpx.ReadError,
    httpx.ReadTimeout,
    httpx.RemoteProtocolError,
    httpx.WriteError,
    httpx.WriteTimeout,
)


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


def _message_content(message: dict[str, Any]) -> str:
    content = message.get("content", "")
    if isinstance(content, str):
        return content
    if isinstance(content, list):
        parts: list[str] = []
        for item in content:
            if isinstance(item, dict) and item.get("type") == "text":
                parts.append(str(item.get("text", "")))
            elif isinstance(item, str):
                parts.append(item)
        return "\n".join(part for part in parts if part)
    return str(content)


class DeepSeekClient:
    """Minimal OpenAI-compatible client for DeepSeek chat completions."""

    def __init__(
        self,
        api_key: str | None = None,
        *,
        base_url: str | None = None,
        model: str | None = None,
        timeout: float = 30.0,
    ) -> None:
        self.api_key = (api_key or os.getenv("DEEPSEEK_API_KEY") or "").strip()
        self.base_url = (
            base_url or os.getenv("DEEPSEEK_API_BASE_URL") or "https://api.deepseek.com"
        ).rstrip("/")
        self.default_model = (
            model
            or os.getenv("DEEPSEEK_MODEL")
            or os.getenv("DEEPSEEK_CHAT_MODEL")
            or "deepseek-chat"
        ).strip()
        self.timeout = timeout
        self._async_client: httpx.AsyncClient | None = None
        self._sync_client: httpx.Client | None = None

    @property
    def available(self) -> bool:
        if self.api_key:
            return True
        env_key = (os.getenv("DEEPSEEK_API_KEY") or "").strip()
        if env_key:
            self.api_key = env_key
            return True
        return False

    def _resolve_model(self, model_name: str | None = None) -> str:
        requested = (model_name or "").strip()
        if not requested or requested.startswith("gemini"):
            return self.default_model
        return requested

    def _build_messages(
        self,
        messages: list[dict[str, Any]],
        system_prompt: str | None = None,
    ) -> list[dict[str, str]]:
        built: list[dict[str, str]] = []
        if system_prompt:
            built.append({"role": "system", "content": system_prompt})
        for message in messages:
            role = str(message.get("role", "user")).strip().lower() or "user"
            if role == "model":
                role = "assistant"
            if role not in {"system", "user", "assistant"}:
                role = "user"
            built.append({"role": role, "content": _message_content(message)})
        return built

    def _headers(self) -> dict[str, str]:
        return {
            "Authorization": f"Bearer {self.api_key}",
            "Content-Type": "application/json",
        }

    def _request_payload(
        self,
        *,
        messages: list[dict[str, Any]],
        system_prompt: str | None,
        model: str | None,
        temperature: float,
        max_tokens: int | None,
        response_format: dict[str, Any] | None,
        stream: bool,
    ) -> dict[str, Any]:
        payload: dict[str, Any] = {
            "model": self._resolve_model(model),
            "messages": self._build_messages(messages, system_prompt),
            "temperature": temperature,
            "stream": stream,
        }
        if max_tokens is not None:
            payload["max_tokens"] = max_tokens
        if response_format is not None:
            payload["response_format"] = response_format
        return payload

    async def _ensure_async_client(self) -> httpx.AsyncClient:
        if self._async_client is None or self._async_client.is_closed:
            self._async_client = httpx.AsyncClient(timeout=self.timeout)
        return self._async_client

    def _ensure_sync_client(self) -> httpx.Client:
        if self._sync_client is None or self._sync_client.is_closed:
            self._sync_client = httpx.Client(timeout=self.timeout)
        return self._sync_client

    @retry(
        retry=retry_if_exception_type(_RETRYABLE_EXCEPTIONS),
        wait=wait_exponential(multiplier=1, min=1, max=8),
        stop=stop_after_attempt(3),
        reraise=True,
    )
    async def _post_async(self, payload: dict[str, Any]) -> dict[str, Any]:
        if not self.available:
            raise RuntimeError("DEEPSEEK_API_KEY is not configured.")
        client = await self._ensure_async_client()
        response = await client.post(
            f"{self.base_url}/chat/completions",
            headers=self._headers(),
            json=payload,
        )
        response.raise_for_status()
        data = response.json()
        if not isinstance(data, dict):
            raise RuntimeError("DeepSeek response was not a JSON object.")
        return data

    @retry(
        retry=retry_if_exception_type(_RETRYABLE_EXCEPTIONS),
        wait=wait_exponential(multiplier=1, min=1, max=8),
        stop=stop_after_attempt(3),
        reraise=True,
    )
    def _post_sync(self, payload: dict[str, Any]) -> dict[str, Any]:
        if not self.available:
            raise RuntimeError("DEEPSEEK_API_KEY is not configured.")
        client = self._ensure_sync_client()
        response = client.post(
            f"{self.base_url}/chat/completions",
            headers=self._headers(),
            json=payload,
        )
        response.raise_for_status()
        data = response.json()
        if not isinstance(data, dict):
            raise RuntimeError("DeepSeek response was not a JSON object.")
        return data

    def _extract_text(self, payload: dict[str, Any]) -> str:
        choices = payload.get("choices")
        if not isinstance(choices, list) or not choices:
            return ""
        message = choices[0].get("message", {})
        if not isinstance(message, dict):
            return ""
        return _message_content(message).strip()

    async def chat_completion(
        self,
        messages: list[dict[str, Any]],
        *,
        system_prompt: str | None = None,
        model: str | None = None,
        temperature: float = 0.3,
        max_tokens: int | None = None,
    ) -> str:
        payload = self._request_payload(
            messages=messages,
            system_prompt=system_prompt,
            model=model,
            temperature=temperature,
            max_tokens=max_tokens,
            response_format=None,
            stream=False,
        )
        data = await self._post_async(payload)
        return self._extract_text(data)

    async def chat_completion_json(
        self,
        messages: list[dict[str, Any]],
        *,
        system_prompt: str | None = None,
        model: str | None = None,
        temperature: float = 0.1,
        max_tokens: int | None = None,
        fallback: dict[str, Any] | None = None,
    ) -> dict[str, Any]:
        payload = self._request_payload(
            messages=messages,
            system_prompt=system_prompt,
            model=model,
            temperature=temperature,
            max_tokens=max_tokens,
            response_format={"type": "json_object"},
            stream=False,
        )
        try:
            data = await self._post_async(payload)
            text = _extract_json_block(self._extract_text(data))
            parsed = json.loads(text) if text else {}
            if isinstance(parsed, dict):
                return parsed
        except Exception as exc:
            logger.error("DeepSeek JSON completion failed: %s", exc, exc_info=True)
        return dict(fallback or {})

    async def stream_chat_completion(
        self,
        messages: list[dict[str, Any]],
        *,
        system_prompt: str | None = None,
        model: str | None = None,
        temperature: float = 0.3,
        max_tokens: int | None = None,
    ) -> AsyncIterator[str]:
        if not self.available:
            return
        payload = self._request_payload(
            messages=messages,
            system_prompt=system_prompt,
            model=model,
            temperature=temperature,
            max_tokens=max_tokens,
            response_format=None,
            stream=True,
        )
        client = await self._ensure_async_client()
        async with client.stream(
            "POST",
            f"{self.base_url}/chat/completions",
            headers=self._headers(),
            json=payload,
        ) as response:
            response.raise_for_status()
            async for line in response.aiter_lines():
                if not line or not line.startswith("data:"):
                    continue
                raw = line[5:].strip()
                if raw == "[DONE]":
                    break
                try:
                    event = json.loads(raw)
                except json.JSONDecodeError:
                    continue
                choices = event.get("choices")
                if not isinstance(choices, list) or not choices:
                    continue
                delta = choices[0].get("delta", {})
                if not isinstance(delta, dict):
                    continue
                chunk = _message_content(delta)
                if chunk:
                    yield chunk

    async def health_check(self) -> dict[str, Any]:
        if not self.available:
            return {
                "status": "unconfigured",
                "model": self.default_model,
                "available": False,
            }
        try:
            text = await self.chat_completion(
                [{"role": "user", "content": "Reply with OK"}],
                temperature=0.0,
                max_tokens=5,
            )
            return {
                "status": "ok" if text else "degraded",
                "model": self.default_model,
                "available": True,
            }
        except Exception as exc:
            logger.warning("DeepSeek health check failed: %s", exc)
            return {
                "status": "degraded",
                "model": self.default_model,
                "available": True,
                "error": str(exc),
            }

    def generate_text(self, *, model_name: str, prompt: str) -> str:
        try:
            payload = self._request_payload(
                messages=[{"role": "user", "content": prompt}],
                system_prompt=None,
                model=model_name,
                temperature=0.3,
                max_tokens=None,
                response_format=None,
                stream=False,
            )
            data = self._post_sync(payload)
            return self._extract_text(data)
        except Exception as exc:
            logger.error("DeepSeek sync text generation failed: %s", exc, exc_info=True)
            return ""

    def generate_json(
        self,
        *,
        model_name: str,
        prompt: str,
        fallback: dict[str, Any] | None = None,
    ) -> dict[str, Any]:
        try:
            payload = self._request_payload(
                messages=[{"role": "user", "content": prompt}],
                system_prompt=None,
                model=model_name,
                temperature=0.1,
                max_tokens=None,
                response_format={"type": "json_object"},
                stream=False,
            )
            data = self._post_sync(payload)
            text = _extract_json_block(self._extract_text(data))
            parsed = json.loads(text) if text else {}
            if isinstance(parsed, dict):
                return parsed
        except Exception as exc:
            logger.error("DeepSeek sync JSON generation failed: %s", exc, exc_info=True)
        return dict(fallback or {})

    async def close(self) -> None:
        if self._async_client is not None and not self._async_client.is_closed:
            await self._async_client.aclose()
        self._async_client = None
        if self._sync_client is not None and not self._sync_client.is_closed:
            self._sync_client.close()
        self._sync_client = None


deepseek_client = DeepSeekClient()


async def chat_completion(
    messages: list[dict[str, Any]],
    *,
    system_prompt: str | None = None,
    model: str | None = None,
    temperature: float = 0.3,
    max_tokens: int | None = None,
) -> str:
    return await deepseek_client.chat_completion(
        messages,
        system_prompt=system_prompt,
        model=model,
        temperature=temperature,
        max_tokens=max_tokens,
    )


async def chat_completion_json(
    messages: list[dict[str, Any]],
    *,
    system_prompt: str | None = None,
    model: str | None = None,
    temperature: float = 0.1,
    max_tokens: int | None = None,
    fallback: dict[str, Any] | None = None,
) -> dict[str, Any]:
    return await deepseek_client.chat_completion_json(
        messages,
        system_prompt=system_prompt,
        model=model,
        temperature=temperature,
        max_tokens=max_tokens,
        fallback=fallback,
    )


async def stream_chat_completion(
    messages: list[dict[str, Any]],
    *,
    system_prompt: str | None = None,
    model: str | None = None,
    temperature: float = 0.3,
    max_tokens: int | None = None,
) -> AsyncIterator[str]:
    async for chunk in deepseek_client.stream_chat_completion(
        messages,
        system_prompt=system_prompt,
        model=model,
        temperature=temperature,
        max_tokens=max_tokens,
    ):
        yield chunk


async def health_check() -> dict[str, Any]:
    return await deepseek_client.health_check()


async def close_client() -> None:
    await deepseek_client.close()
