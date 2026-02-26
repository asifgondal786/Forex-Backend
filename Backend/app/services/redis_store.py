"""Optional Redis integration for queueing and websocket registry state."""

from __future__ import annotations

import asyncio
import json
import os
import time
from typing import Any

try:
    import redis.asyncio as redis_async  # type: ignore[import-not-found]
except Exception:  # pragma: no cover - optional dependency
    redis_async = None


def _env_bool(name: str, default: bool = False) -> bool:
    value = os.getenv(name)
    if value is None:
        return default
    return value.strip().lower() in {"1", "true", "yes", "on"}


def _env_float(name: str, default: float, minimum: float = 0.0) -> float:
    value = os.getenv(name)
    if value is None:
        return default
    try:
        parsed = float(value.strip())
    except Exception:
        return default
    return parsed if parsed >= minimum else default


class RedisStore:
    def __init__(self) -> None:
        self._client: Any | None = None
        self._lock = asyncio.Lock()
        self._next_connect_attempt = 0.0
        self._warned_missing_dependency = False

    def is_enabled(self) -> bool:
        if _env_bool("REDIS_ENABLED", False):
            return True
        queue_backend = (os.getenv("TASK_QUEUE_BACKEND") or "memory").strip().lower()
        if queue_backend == "redis":
            return True
        if _env_bool("WS_REDIS_REGISTRY_ENABLED", False):
            return True
        return False

    def is_connected(self) -> bool:
        return self._client is not None

    async def ensure_connected(self) -> bool:
        if self._client is not None:
            return True
        if not self.is_enabled():
            return False

        now = time.monotonic()
        if now < self._next_connect_attempt:
            return False

        if redis_async is None:
            if not self._warned_missing_dependency:
                print("[Redis] redis package not installed; redis-backed features disabled.")
                self._warned_missing_dependency = True
            return False

        async with self._lock:
            if self._client is not None:
                return True

            now = time.monotonic()
            if now < self._next_connect_attempt:
                return False

            redis_url = (os.getenv("REDIS_URL") or "redis://localhost:6379/0").strip()
            connect_timeout = _env_float("REDIS_CONNECT_TIMEOUT_SECONDS", 2.0, minimum=0.1)
            socket_timeout = _env_float("REDIS_SOCKET_TIMEOUT_SECONDS", 2.0, minimum=0.1)
            retry_seconds = _env_float("REDIS_RETRY_SECONDS", 5.0, minimum=0.1)

            client = None
            try:
                client = redis_async.from_url(
                    redis_url,
                    encoding="utf-8",
                    decode_responses=True,
                    socket_connect_timeout=connect_timeout,
                    socket_timeout=socket_timeout,
                    health_check_interval=30,
                )
                await client.ping()
                self._client = client
                self._next_connect_attempt = 0.0
                print(f"[Redis] Connected to {redis_url}")
                return True
            except Exception as exc:
                self._next_connect_attempt = time.monotonic() + retry_seconds
                if client is not None:
                    try:
                        await client.close()
                    except Exception:
                        pass
                print(f"[Redis] Connection failed: {exc}")
                return False

    async def close(self) -> None:
        client = self._client
        self._client = None
        if client is None:
            return
        try:
            await client.close()
            print("[Redis] Connection closed")
        except Exception:
            pass

    async def push_queue_item(self, queue_key: str, item: dict[str, Any]) -> bool:
        if not await self.ensure_connected():
            return False
        assert self._client is not None
        try:
            payload = json.dumps(item, separators=(",", ":"), default=str)
            await self._client.rpush(queue_key, payload)
            return True
        except Exception as exc:
            print(f"[Redis] Failed to enqueue item on {queue_key}: {exc}")
            return False

    async def pop_queue_item(self, queue_key: str, timeout_seconds: int = 1) -> dict[str, Any] | None:
        if not await self.ensure_connected():
            return None
        assert self._client is not None
        try:
            result = await self._client.blpop(queue_key, timeout=max(1, int(timeout_seconds)))
            if not result:
                return None
            _key, raw = result
            if not raw:
                return None
            parsed = json.loads(raw)
            if isinstance(parsed, dict):
                return parsed
            return None
        except Exception as exc:
            print(f"[Redis] Failed to pop item on {queue_key}: {exc}")
            return None

    async def get_queue_length(self, queue_key: str) -> int:
        if not await self.ensure_connected():
            return 0
        assert self._client is not None
        try:
            length = await self._client.llen(queue_key)
            return max(0, int(length))
        except Exception:
            return 0

    async def set_ws_connection(self, connection_id: str, metadata: dict[str, Any]) -> bool:
        if not await self.ensure_connected():
            return False
        assert self._client is not None
        key = os.getenv("WS_REDIS_REGISTRY_KEY", "forex:ws:registry")
        payload = dict(metadata)
        payload["connection_id"] = connection_id
        try:
            await self._client.hset(
                key,
                connection_id,
                json.dumps(payload, separators=(",", ":"), default=str),
            )
            return True
        except Exception as exc:
            print(f"[Redis] Failed to set ws connection {connection_id}: {exc}")
            return False

    async def patch_ws_connection(self, connection_id: str, updates: dict[str, Any]) -> bool:
        if not await self.ensure_connected():
            return False
        assert self._client is not None
        key = os.getenv("WS_REDIS_REGISTRY_KEY", "forex:ws:registry")
        try:
            raw = await self._client.hget(key, connection_id)
            if raw:
                try:
                    payload = json.loads(raw)
                    if not isinstance(payload, dict):
                        payload = {}
                except Exception:
                    payload = {}
            else:
                payload = {}
            payload.update(updates or {})
            payload["connection_id"] = connection_id
            await self._client.hset(
                key,
                connection_id,
                json.dumps(payload, separators=(",", ":"), default=str),
            )
            return True
        except Exception as exc:
            print(f"[Redis] Failed to patch ws connection {connection_id}: {exc}")
            return False

    async def remove_ws_connection(self, connection_id: str) -> bool:
        if not await self.ensure_connected():
            return False
        assert self._client is not None
        key = os.getenv("WS_REDIS_REGISTRY_KEY", "forex:ws:registry")
        try:
            await self._client.hdel(key, connection_id)
            return True
        except Exception as exc:
            print(f"[Redis] Failed to remove ws connection {connection_id}: {exc}")
            return False

    async def get_ws_registry(self, task_id: str | None = None) -> dict[str, dict[str, Any]]:
        if not await self.ensure_connected():
            return {}
        assert self._client is not None
        key = os.getenv("WS_REDIS_REGISTRY_KEY", "forex:ws:registry")
        try:
            entries = await self._client.hgetall(key)
        except Exception as exc:
            print(f"[Redis] Failed to fetch ws registry: {exc}")
            return {}

        snapshot: dict[str, dict[str, Any]] = {}
        for connection_id, raw in (entries or {}).items():
            try:
                parsed = json.loads(raw)
            except Exception:
                continue
            if not isinstance(parsed, dict):
                continue
            if task_id is not None and parsed.get("task_id") != task_id:
                continue
            snapshot[str(connection_id)] = parsed
        return snapshot


redis_store = RedisStore()
