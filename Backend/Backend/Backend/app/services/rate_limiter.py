from __future__ import annotations
import time
from collections import deque

class RateLimiter:
    def __init__(self, limit: int, window: float) -> None:
        self.limit = limit
        self.window = window
        self._memory: dict[str, deque] = {}

    async def check(self, key: str) -> bool:
        try:
            from .redis_store import redis_store
            if redis_store.is_enabled():
                allowed, _ = await redis_store.sliding_window_check(key=key, limit=self.limit, window_seconds=self.window)
                return allowed
        except Exception:
            pass
        return self._memory_check(key)

    def _memory_check(self, key: str) -> bool:
        now = time.time()
        window_start = now - self.window
        if key not in self._memory:
            self._memory[key] = deque()
        bucket = self._memory[key]
        while bucket and bucket[0] <= window_start:
            bucket.popleft()
        if len(bucket) >= self.limit:
            return False
        bucket.append(now)
        return True
