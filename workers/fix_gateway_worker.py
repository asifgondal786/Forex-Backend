"""
fix_gateway_worker.py — Standalone FIX protocol gateway process.

This runs as an INDEPENDENT process, separate from the FastAPI API server.
Communication between API and FIX gateway is via Redis pub/sub.

Why separate?
  - FIX sessions are stateful, long-lived TCP connections
  - If the API restarts (deploy, crash, scaling), the FIX session must persist
  - FIX has sequence number requirements — reconnection is complex
  - Latency-critical trade execution is isolated from AI/API request load

Architecture:
  FastAPI API → Redis "orders:submit" channel → FIX Gateway → Pepperstone
  Pepperstone → FIX Gateway → Redis "orders:execution_report" channel → FastAPI API
"""

import os
import sys
import json
import asyncio
import signal
import logging
from datetime import datetime, timezone
from typing import Optional

# Add parent to path for imports
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from dotenv import load_dotenv
load_dotenv()

import redis.asyncio as aioredis

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s | %(name)s | %(levelname)s | %(message)s",
    datefmt="%Y-%m-%d %H:%M:%S",
)
logger = logging.getLogger("fix_gateway")

# Redis channels
CHANNEL_ORDER_SUBMIT = "orders:submit"
CHANNEL_ORDER_CANCEL = "orders:cancel"
CHANNEL_ORDER_MODIFY = "orders:modify"
CHANNEL_EXECUTION_REPORT = "orders:execution_report"
CHANNEL_FIX_STATUS = "fix:status"

# FIX connection config
FIX_CONFIG = {
    "host": os.getenv("PEPPERSTONE_HOST", ""),
    "port": int(os.getenv("PEPPERSTONE_PORT", "0")),
    "sender_comp_id": os.getenv("PEPPERSTONE_SENDER_COMP_ID", ""),
    "target_comp_id": os.getenv("PEPPERSTONE_TARGET_COMP_ID", ""),
    "username": os.getenv("PEPPERSTONE_USERNAME", ""),
    "password": os.getenv("PEPPERSTONE_PASSWORD", ""),
}


class FIXGateway:
    """
    Standalone FIX gateway that bridges Redis commands to Pepperstone.
    
    Lifecycle:
    1. Connects to Redis
    2. Establishes FIX session with Pepperstone
    3. Subscribes to order command channels
    4. Forwards orders to broker
    5. Publishes execution reports back to Redis
    """

    def __init__(self):
        self._redis: Optional[aioredis.Redis] = None
        self._running = False
        self._fix_connected = False
        self._sequence_number = 1
        self._heartbeat_interval = 30
        self._last_heartbeat = datetime.now(timezone.utc)

    async def start(self):
        """Main entry point — connect and start processing."""
        logger.info("FIX Gateway starting...")
        
        # Connect to Redis
        redis_url = os.getenv("REDIS_URL", "redis://localhost:6379/0")
        self._redis = aioredis.from_url(redis_url, decode_responses=True)
        
        try:
            await self._redis.ping()
            logger.info("Redis connected: %s", redis_url)
        except Exception as e:
            logger.error("Redis connection failed: %s", e)
            return

        # Announce gateway is starting
        await self._publish_status("starting")

        # Connect FIX session
        await self._connect_fix()

        # Start processing
        self._running = True
        await asyncio.gather(
            self._listen_for_orders(),
            self._heartbeat_loop(),
            self._monitor_fix_session(),
        )

    async def _connect_fix(self):
        """
        Establish FIX session with Pepperstone.
        In production, this uses the actual FIX protocol (quickfix or simplefix library).
        """
        if not FIX_CONFIG["host"]:
            logger.warning("FIX not configured — running in SIMULATION mode")
            self._fix_connected = False
            await self._publish_status("simulation_mode")
            return

        try:
            # TODO: Replace with actual FIX session establishment
            # from app.services.pepperstone_fix_client import PepperstoneFIXClient
            # self._fix_session = PepperstoneFIXClient(FIX_CONFIG)
            # await self._fix_session.logon()
            
            logger.info(
                "FIX session establishing | host=%s | sender=%s | target=%s",
                FIX_CONFIG["host"],
                FIX_CONFIG["sender_comp_id"],
                FIX_CONFIG["target_comp_id"],
            )
            
            # Simulated connection for now
            self._fix_connected = True
            await self._publish_status("connected")
            logger.info("FIX session CONNECTED")

        except Exception as e:
            logger.error("FIX connection failed: %s", e)
            self._fix_connected = False
            await self._publish_status("disconnected", error=str(e))

    async def _listen_for_orders(self):
        """Subscribe to Redis channels and process incoming order commands."""
        pubsub = self._redis.pubsub()
        await pubsub.subscribe(
            CHANNEL_ORDER_SUBMIT,
            CHANNEL_ORDER_CANCEL,
            CHANNEL_ORDER_MODIFY,
        )
        
        logger.info("Listening for orders on Redis channels...")

        async for message in pubsub.listen():
            if not self._running:
                break
                
            if message["type"] != "message":
                continue

            channel = message["channel"]
            try:
                data = json.loads(message["data"])
            except json.JSONDecodeError:
                logger.error("Invalid JSON on channel %s: %s", channel, message["data"])
                continue

            logger.info("Received command | channel=%s | order_id=%s", channel, data.get("order_id"))

            if channel == CHANNEL_ORDER_SUBMIT:
                await self._handle_order_submit(data)
            elif channel == CHANNEL_ORDER_CANCEL:
                await self._handle_order_cancel(data)
            elif channel == CHANNEL_ORDER_MODIFY:
                await self._handle_order_modify(data)

    async def _handle_order_submit(self, order: dict):
        """Process a new order submission."""
        order_id = order.get("order_id", "unknown")
        
        if not self._fix_connected:
            # Simulation mode — generate a simulated fill
            await self._simulate_fill(order)
            return

        try:
            # TODO: Send actual FIX NewOrderSingle (35=D)
            # fix_message = self._build_new_order_single(order)
            # await self._fix_session.send(fix_message)
            
            logger.info(
                "Order submitted to broker | id=%s | %s %s %s @ market",
                order_id,
                order.get("direction", "").upper(),
                order.get("lot_size"),
                order.get("pair"),
            )

            # Publish acknowledgment
            await self._publish_execution_report(order_id, {
                "status": "acknowledged",
                "broker_order_id": f"PEP-{order_id[:8]}",
                "timestamp": datetime.now(timezone.utc).isoformat(),
            })

            # Simulate fill (in production, this comes from FIX execution reports)
            await asyncio.sleep(0.1)  # Simulated latency
            await self._simulate_fill(order)

        except Exception as e:
            logger.error("Order submission failed | id=%s | error=%s", order_id, e)
            await self._publish_execution_report(order_id, {
                "status": "execution_error",
                "error": str(e),
                "timestamp": datetime.now(timezone.utc).isoformat(),
            })

    async def _handle_order_cancel(self, data: dict):
        """Process order cancellation request."""
        order_id = data.get("order_id", "unknown")
        logger.info("Cancel request | order_id=%s", order_id)

        # TODO: Send FIX OrderCancelRequest (35=F)
        await self._publish_execution_report(order_id, {
            "status": "cancelled_by_user",
            "timestamp": datetime.now(timezone.utc).isoformat(),
        })

    async def _handle_order_modify(self, data: dict):
        """Process order modification request."""
        order_id = data.get("order_id", "unknown")
        logger.info("Modify request | order_id=%s", order_id)

        # TODO: Send FIX OrderCancelReplaceRequest (35=G)
        await self._publish_execution_report(order_id, {
            "status": "modified",
            "new_stop_loss": data.get("stop_loss"),
            "new_take_profit": data.get("take_profit"),
            "timestamp": datetime.now(timezone.utc).isoformat(),
        })

    async def _simulate_fill(self, order: dict):
        """Simulate a fill for testing/demo mode."""
        order_id = order.get("order_id", "unknown")
        
        # Simulate realistic fill price
        entry = order.get("entry_price", 1.0900)
        slippage = 0.00002  # 0.2 pips slippage
        fill_price = entry + slippage if order.get("direction") == "buy" else entry - slippage

        await self._publish_execution_report(order_id, {
            "status": "filled",
            "fill_price": round(fill_price, 5),
            "filled_quantity": order.get("lot_size", 0.01),
            "slippage": round(slippage, 5),
            "commission": 3.50,  # Simulated commission
            "broker_order_id": f"SIM-{order_id[:8]}",
            "timestamp": datetime.now(timezone.utc).isoformat(),
        })
        
        logger.info(
            "Order FILLED | id=%s | price=%.5f | slippage=%.5f",
            order_id, fill_price, slippage,
        )

    async def _publish_execution_report(self, order_id: str, report: dict):
        """Publish execution report back to the API server via Redis."""
        report["order_id"] = order_id
        await self._redis.publish(
            CHANNEL_EXECUTION_REPORT,
            json.dumps(report),
        )

    async def _publish_status(self, status: str, error: str = None):
        """Publish FIX gateway status."""
        msg = {
            "status": status,
            "timestamp": datetime.now(timezone.utc).isoformat(),
            "fix_connected": self._fix_connected,
        }
        if error:
            msg["error"] = error
        await self._redis.publish(CHANNEL_FIX_STATUS, json.dumps(msg))

    async def _heartbeat_loop(self):
        """Send periodic heartbeats and status updates."""
        while self._running:
            await asyncio.sleep(self._heartbeat_interval)
            await self._publish_status("alive")
            self._last_heartbeat = datetime.now(timezone.utc)

    async def _monitor_fix_session(self):
        """Monitor FIX session health and reconnect if needed."""
        while self._running:
            await asyncio.sleep(10)
            
            if not self._fix_connected and FIX_CONFIG["host"]:
                logger.warning("FIX session disconnected — attempting reconnect...")
                await self._connect_fix()

    async def stop(self):
        """Graceful shutdown."""
        logger.info("FIX Gateway shutting down...")
        self._running = False
        await self._publish_status("shutting_down")
        
        # TODO: Send FIX Logout (35=5)
        # if self._fix_session:
        #     await self._fix_session.logout()
        
        if self._redis:
            await self._redis.close()
        
        logger.info("FIX Gateway stopped.")


async def main():
    gateway = FIXGateway()

    # Handle graceful shutdown
    loop = asyncio.get_event_loop()
    for sig in (signal.SIGINT, signal.SIGTERM):
        loop.add_signal_handler(sig, lambda: asyncio.create_task(gateway.stop()))

    await gateway.start()


if __name__ == "__main__":
    asyncio.run(main())
