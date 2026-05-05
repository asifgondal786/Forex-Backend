"""
idempotent_execution_service.py — Ensures trade requests are processed exactly once.
Prevents duplicate executions from network retries, double-clicks, or reconnections.
"""

import hashlib
import logging
from datetime import datetime, timezone, timedelta
from typing import Optional

from app.services.redis_store import get_redis

logger = logging.getLogger(__name__)

# Idempotency key TTL — how long we remember a processed request
IDEMPOTENCY_TTL = timedelta(hours=24)


class IdempotencyService:
    """
    Implements idempotency for trade execution.
    
    Flow:
    1. Client sends trade request with `X-Idempotency-Key` header
    2. Backend checks if this key was already processed
    3. If yes → return cached result (no duplicate execution)
    4. If no → execute trade, cache result, return to client
    
    Key format: user_id:action:hash(parameters)
    """

    @staticmethod
    def generate_key(user_id: str, action: str, params: dict) -> str:
        """Generate a deterministic idempotency key from request parameters."""
        # Sort params for consistent hashing regardless of key order
        param_str = str(sorted(params.items()))
        hash_input = f"{user_id}:{action}:{param_str}"
        return hashlib.sha256(hash_input.encode()).hexdigest()[:32]

    @staticmethod
    async def check_and_lock(idempotency_key: str) -> Optional[dict]:
        """
        Check if this request was already processed.
        
        Returns:
            - None if this is a new request (and sets a processing lock)
            - Cached response dict if already processed
        """
        redis = await get_redis()
        cache_key = f"idempotency:{idempotency_key}"

        # Check if already processed
        cached = await redis.get(cache_key)
        if cached:
            import json
            result = json.loads(cached)
            logger.info(
                "Idempotency hit | key=%s | returning cached result",
                idempotency_key,
            )
            return result

        # Set a processing lock (prevents race conditions)
        lock_key = f"idempotency_lock:{idempotency_key}"
        acquired = await redis.set(lock_key, "processing", ex=30, nx=True)

        if not acquired:
            # Another instance is currently processing this request
            logger.warning(
                "Idempotency lock contention | key=%s | request in progress",
                idempotency_key,
            )
            raise IdempotencyConflictError(
                "This request is currently being processed. Please wait."
            )

        return None  # New request, proceed with execution

    @staticmethod
    async def store_result(idempotency_key: str, result: dict):
        """Store the execution result for future duplicate detection."""
        import json
        redis = await get_redis()
        cache_key = f"idempotency:{idempotency_key}"
        lock_key = f"idempotency_lock:{idempotency_key}"

        result["_cached_at"] = datetime.now(timezone.utc).isoformat()
        await redis.set(
            cache_key,
            json.dumps(result),
            ex=int(IDEMPOTENCY_TTL.total_seconds()),
        )
        # Release the processing lock
        await redis.delete(lock_key)

        logger.info("Idempotency stored | key=%s", idempotency_key)

    @staticmethod
    async def invalidate(idempotency_key: str):
        """Explicitly invalidate a cached result (e.g., after order cancellation)."""
        redis = await get_redis()
        await redis.delete(f"idempotency:{idempotency_key}")
        await redis.delete(f"idempotency_lock:{idempotency_key}")


class IdempotencyConflictError(Exception):
    """Raised when a duplicate request is detected mid-processing."""
    pass
