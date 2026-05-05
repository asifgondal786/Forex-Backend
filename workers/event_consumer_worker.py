"""
event_consumer_worker.py — Standalone worker that processes domain events.

Runs as a separate process from the API server.
Consumes events from Redis Streams and dispatches to handlers.

Start with:
    python workers/event_consumer_worker.py
"""

import os
import sys
import asyncio
import signal
import logging

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from dotenv import load_dotenv
load_dotenv()

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s | %(name)s | %(levelname)s | %(message)s",
)
logger = logging.getLogger("event_worker")


async def main():
    from app.services.event_bus import EventConsumer, EventType
    from app.services.event_handlers import (
        handle_trade_notification,
        handle_portfolio_update,
        handle_copy_trade_propagation,
        handle_risk_alert,
        handle_audit_log,
    )

    consumer = EventConsumer("main-worker-1")

    # Register handlers
    consumer.register(EventType.TRADE_OPENED, handle_trade_notification)
    consumer.register(EventType.TRADE_CLOSED, handle_trade_notification)
    consumer.register(EventType.TRADE_CLOSED, handle_portfolio_update)
    consumer.register(EventType.TRADE_OPENED, handle_copy_trade_propagation)
    consumer.register(EventType.ORDER_FILLED, handle_trade_notification)
    consumer.register(EventType.ORDER_REJECTED, handle_trade_notification)
    consumer.register(EventType.RISK_LIMIT_BREACHED, handle_risk_alert)
    consumer.register(EventType.RISK_DRAWDOWN_WARNING, handle_risk_alert)
    consumer.register(EventType.RISK_POSITION_FORCE_CLOSED, handle_risk_alert)
    consumer.register(EventType.SIGNAL_GENERATED, handle_trade_notification)

    # All events get audited
    for event_type in EventType:
        consumer.register(event_type, handle_audit_log)

    logger.info("Event consumer starting with %d handler registrations", len(EventType))

    # Graceful shutdown
    loop = asyncio.get_event_loop()
    for sig in (signal.SIGINT, signal.SIGTERM):
        loop.add_signal_handler(sig, consumer.stop)

    await consumer.start()


if __name__ == "__main__":
    asyncio.run(main())
