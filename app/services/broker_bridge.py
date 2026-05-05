"""
broker_bridge.py — API-side bridge to the FIX Gateway worker.
Submits orders via Redis pub/sub and listens for execution reports.

This replaces direct FIX calls from the API process.
The actual FIX connection lives in workers/fix_gateway_worker.py.
"""

import json
import logging
import asyncio
from datetime import datetime, timezone
from typing import Optional, Callable

from app.services.redis_store import get_redis

logger = logging.getLogger(__name__)

# Redis channels (must match fix_gateway_worker.py)
CHANNEL_ORDER_SUBMIT = "orders:submit"
CHANNEL_ORDER_CANCEL = "orders:cancel"
CHANNEL_ORDER_MODIFY = "orders:modify"
CHANNEL_EXECUTION_REPORT = "orders:execution_report"
CHANNEL_FIX_STATUS = "fix:status"


class BrokerBridge:
    """
    Sends order commands to the FIX Gateway via Redis and receives execution reports.
    
    Usage:
        bridge = BrokerBridge()
        report = await bridge.submit_order(order_data)
    """

    def __init__(self, timeout: float = 30.0):
        self.timeout = timeout

    async def submit_order(self, order: dict) -> dict:
        """
        Submit an order to the FIX gateway and wait for execution report.
        
        Args:
            order: dict with order_id, pair, direction, lot_size, etc.
        
        Returns:
            Execution report dict from the broker
            
        Raises:
            TimeoutError: If no response within timeout
        """
        redis = await get_redis()
        order_id = order.get("order_id")

        if not order_id:
            raise ValueError("order_id is required")

        # Publish order to FIX gateway
        await redis.publish(
            CHANNEL_ORDER_SUBMIT,
            json.dumps(order),
        )
        logger.info("Order published to FIX gateway | id=%s", order_id)

        # Wait for execution report
        report = await self._wait_for_report(order_id)
        return report

    async def cancel_order(self, order_id: str, reason: str = "") -> dict:
        """Request order cancellation via FIX gateway."""
        redis = await get_redis()
        
        await redis.publish(
            CHANNEL_ORDER_CANCEL,
            json.dumps({"order_id": order_id, "reason": reason}),
        )
        logger.info("Cancel request published | id=%s", order_id)

        return await self._wait_for_report(order_id)

    async def modify_order(
        self, order_id: str, stop_loss: Optional[float] = None, take_profit: Optional[float] = None
    ) -> dict:
        """Request order modification via FIX gateway."""
        redis = await get_redis()
        
        payload = {"order_id": order_id}
        if stop_loss is not None:
            payload["stop_loss"] = stop_loss
        if take_profit is not None:
            payload["take_profit"] = take_profit

        await redis.publish(CHANNEL_ORDER_MODIFY, json.dumps(payload))
        logger.info("Modify request published | id=%s", order_id)

        return await self._wait_for_report(order_id)

    async def get_fix_status(self) -> dict:
        """Check if the FIX gateway is alive and connected."""
        redis = await get_redis()
        
        # Check the last published status (stored as a key for quick access)
        status_raw = await redis.get("fix:last_status")
        if status_raw:
            return json.loads(status_raw)
        return {"status": "unknown", "fix_connected": False}

    async def _wait_for_report(self, order_id: str) -> dict:
        """
        Subscribe to execution reports and wait for one matching our order_id.
        Uses a temporary subscriber with timeout.
        """
        redis = await get_redis()
        pubsub = redis.pubsub()
        await pubsub.subscribe(CHANNEL_EXECUTION_REPORT)

        try:
            deadline = asyncio.get_event_loop().time() + self.timeout

            async for message in pubsub.listen():
                if asyncio.get_event_loop().time() > deadline:
                    raise TimeoutError(
                        f"No execution report for order {order_id} within {self.timeout}s"
                    )

                if message["type"] != "message":
                    continue

                try:
                    report = json.loads(message["data"])
                except json.JSONDecodeError:
                    continue

                if report.get("order_id") == order_id:
                    logger.info(
                        "Execution report received | id=%s | status=%s",
                        order_id, report.get("status"),
                    )
                    return report

        finally:
            await pubsub.unsubscribe(CHANNEL_EXECUTION_REPORT)
            await pubsub.close()

        raise TimeoutError(f"No execution report for order {order_id}")


# Singleton instance
broker_bridge = BrokerBridge()
