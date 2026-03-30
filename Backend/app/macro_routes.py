"""
Tajir Macro Event Shield â€” Scheduler + FastAPI Routes
Phase 18

Add to your main FastAPI app:
    from macro_routes import macro_router, start_shield_scheduler, stop_shield_scheduler
    app.include_router(macro_router, prefix="/api/v1")
    app.add_event_handler("startup",  start_shield_scheduler)
    app.add_event_handler("shutdown", stop_shield_scheduler)
"""

from __future__ import annotations

import logging
from datetime import datetime, timezone, timedelta

from fastapi import APIRouter, Query, HTTPException
try:
    from apscheduler.schedulers.asyncio import AsyncIOScheduler
    SCHEDULER_AVAILABLE = True
except ImportError:
    AsyncIOScheduler = None
    SCHEDULER_AVAILABLE = False
    print("[WARN] apscheduler not installed - macro shield scheduler disabled")
from apscheduler.triggers.interval import IntervalTrigger

from app.macro_models import (
    UpcomingEventsResponse, ShieldStatusResponse,
    NewsWindowResult,
)
from macro_shield import (
    refresh_event_cache,
    dispatch_pre_event_alerts,
    check_news_window,
    get_upcoming_events,
)

logger   = logging.getLogger("macro_shield.routes")
macro_router = APIRouter(tags=["Macro Event Shield"])

# Global scheduler instance
_scheduler: AsyncIOScheduler | None = None


# â”€â”€â”€ Scheduler Lifecycle â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

async def start_shield_scheduler(supabase=None, notification_service=None):
    """
    Called on FastAPI startup.
    Starts two jobs:
        1. Refresh event cache every 30 minutes
        2. Dispatch pre-event alerts every 5 minutes (lightweight check)
    Also runs an immediate refresh on startup so the cache is warm instantly.
    """
    global _scheduler

    _scheduler = AsyncIOScheduler(timezone="UTC")

    # Job 1: Refresh cache from Forex Factory
    _scheduler.add_job(
        func=lambda: refresh_event_cache(supabase),
        trigger=IntervalTrigger(minutes=30),
        id="macro_cache_refresh",
        name="Macro event cache refresh",
        replace_existing=True,
        max_instances=1,
    )

    # Job 2: Check and dispatch pre-event alerts
    _scheduler.add_job(
        func=lambda: dispatch_pre_event_alerts(supabase, notification_service),
        trigger=IntervalTrigger(minutes=5),
        id="macro_alert_dispatch",
        name="Macro pre-event alert dispatch",
        replace_existing=True,
        max_instances=1,
    )

    _scheduler.start()
    logger.info("Macro Event Shield scheduler started")

    # Warm the cache immediately on startup
    await refresh_event_cache(supabase)
    logger.info("Initial macro event cache loaded")


async def stop_shield_scheduler():
    global _scheduler
    if _scheduler and _scheduler.running:
        _scheduler.shutdown(wait=False)
        logger.info("Macro Event Shield scheduler stopped")


# â”€â”€â”€ Routes â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

@macro_router.get("/macro/upcoming", response_model=UpcomingEventsResponse)
async def get_upcoming(
    hours: int = Query(default=24, ge=1, le=168, description="Hours ahead to look"),
    currencies: str = Query(default="USD,EUR,GBP,JPY", description="Comma-separated currency codes"),
):
    """
    Returns upcoming high-impact events for the requested currencies.
    Used by the frontend EventShieldPanel to show the next events.
    """
    currency_list = [c.strip().upper() for c in currencies.split(",")]
    events = await get_upcoming_events(currencies=currency_list, hours_ahead=hours)

    now = datetime.now(tz=timezone.utc)
    return UpcomingEventsResponse(
        events=events,
        fetched_at=now,
        next_refresh=now + timedelta(minutes=30),
    )


@macro_router.get("/macro/status/{symbol}", response_model=ShieldStatusResponse)
async def get_shield_status(symbol: str):
    """
    Returns the current shield status for a trading symbol.
    Called by the frontend before showing the trade form.
    Also called by the autonomous engine before placing any trade.
    """
    symbol = symbol.upper()
    window_result = await check_news_window(symbol)
    upcoming      = await get_upcoming_events(hours_ahead=4)

    # Filter upcoming to only events relevant to this symbol's currencies
    from macro_scraper import currencies_for_symbol
    pair_currencies = set(currencies_for_symbol(symbol))
    relevant = [e for e in upcoming if e.currency in pair_currencies][:3]

    return ShieldStatusResponse(
        symbol=symbol,
        window_result=window_result,
        upcoming=relevant,
    )


@macro_router.post("/macro/refresh", status_code=202)
async def force_refresh():
    """
    Manually trigger a cache refresh.
    Useful for testing or after a failed scheduled refresh.
    Protected â€” add your auth dependency in production.
    """
    events = await refresh_event_cache()
    return {
        "message": f"Cache refreshed â€” {len(events)} high-impact events loaded",
        "refreshed_at": datetime.now(tz=timezone.utc).isoformat(),
    }


@macro_router.get("/macro/health")
async def shield_health():
    """Quick health check for the shield â€” shows cache age and event count."""
    from macro_shield import _cache_fetched_at, _event_cache
    now = datetime.now(tz=timezone.utc)
    age_minutes = (
        round((now - _cache_fetched_at).total_seconds() / 60, 1)
        if _cache_fetched_at else None
    )
    return {
        "status":             "ok",
        "cached_events":      len(_event_cache),
        "cache_age_minutes":  age_minutes,
        "scheduler_running":  _scheduler.running if _scheduler else False,
    }