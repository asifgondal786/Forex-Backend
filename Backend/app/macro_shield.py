"""
Tajir Macro Event Shield — Core Engine
Phase 18

Responsibilities:
  1. Cache fetched events in Supabase (macro_events table)
  2. Check if a given symbol is inside a ±30 min news window
  3. Dispatch pre-event alerts via WhatsApp / SMS / Push
  4. Expose is_news_window() used by Risk Guardian MarketSnapshot
"""

from __future__ import annotations

import asyncio
import logging
from datetime import datetime, timezone, timedelta
from typing import Optional

from macro_models import (
    MacroEvent, EventImpact, NewsWindowResult,
    EventAlert, AlertChannel, AlertStatus,
    UpcomingEventsResponse, ShieldStatusResponse,
)
from macro_scraper import fetch_calendar_events, currencies_for_symbol

logger = logging.getLogger("macro_shield.engine")

# ─── Config ───────────────────────────────────────────────────────────────────

BLOCK_WINDOW_MINUTES   = 30     # block ±30 min around event
ALERT_ADVANCE_MINUTES  = 60     # send alert 60 min before event
CACHE_TTL_MINUTES      = 30     # refresh cache every 30 min
MONITORED_CURRENCIES   = {"USD", "EUR", "GBP", "JPY"}


# ─── In-Memory Cache (backed by Supabase for persistence) ────────────────────

_event_cache: list[MacroEvent] = []
_cache_fetched_at: Optional[datetime] = None
_alert_sent_ids: set[str] = set()   # tracks which events have had alerts sent


# ─── Cache Layer ──────────────────────────────────────────────────────────────

async def refresh_event_cache(supabase=None) -> list[MacroEvent]:
    """
    Fetch fresh events from Forex Factory and store in Supabase.
    Called by the scheduler every 30 minutes.
    """
    global _event_cache, _cache_fetched_at

    logger.info("Refreshing macro event cache from Forex Factory...")
    events = await fetch_calendar_events(days_ahead=7)

    _event_cache      = events
    _cache_fetched_at = datetime.now(tz=timezone.utc)

    if supabase and events:
        await _upsert_events_to_supabase(supabase, events)

    logger.info("Cache refreshed: %d high-impact events loaded", len(events))
    return events


async def get_cached_events(supabase=None) -> list[MacroEvent]:
    """
    Return cached events. Refresh if cache is stale or empty.
    """
    global _event_cache, _cache_fetched_at

    cache_stale = (
        _cache_fetched_at is None or
        (datetime.now(tz=timezone.utc) - _cache_fetched_at).total_seconds() > CACHE_TTL_MINUTES * 60
    )

    if cache_stale or not _event_cache:
        await refresh_event_cache(supabase)

    return _event_cache


async def _upsert_events_to_supabase(supabase, events: list[MacroEvent]):
    """
    Upsert events to Supabase macro_events table.
    Uses (title + event_time + currency) as natural key.

    Replace stub with:
        supabase.table("macro_events").upsert(rows, on_conflict="title,event_time,currency").execute()
    """
    rows = [
        {
            "title":       e.title,
            "currency":    e.currency,
            "impact":      e.impact.value,
            "event_time":  e.event_time.isoformat(),
            "forecast":    e.forecast,
            "previous":    e.previous,
            "actual":      e.actual,
            "source":      e.source,
            "fetched_at":  e.fetched_at.isoformat() if e.fetched_at else None,
        }
        for e in events
    ]
    try:
        # supabase.table("macro_events").upsert(rows, on_conflict="title,event_time,currency").execute()
        logger.debug("Upserted %d events to Supabase macro_events", len(rows))
    except Exception as e:
        logger.error("Supabase upsert failed: %s", e)


# ─── Window Checker ───────────────────────────────────────────────────────────

async def check_news_window(
    symbol: str,
    supabase=None,
) -> NewsWindowResult:
    """
    Check if the given symbol is within ±30 min of a high-impact news event.
    Returns a NewsWindowResult — is_blocked=True means the Risk Guardian
    should set is_news_window=True on the MarketSnapshot.
    """
    currencies = currencies_for_symbol(symbol)
    monitored  = [c for c in currencies if c in MONITORED_CURRENCIES]

    if not monitored:
        return NewsWindowResult(
            is_blocked=False,
            symbol=symbol,
            reason=f"No monitored currencies in {symbol}",
        )

    events = await get_cached_events(supabase)
    now    = datetime.now(tz=timezone.utc)
    window = timedelta(minutes=BLOCK_WINDOW_MINUTES)

    for event in events:
        if event.currency not in monitored:
            continue
        if event.impact != EventImpact.HIGH:
            continue

        delta = event.event_time - now
        minutes_to = delta.total_seconds() / 60

        # Inside window: event is within ±30 minutes
        if -BLOCK_WINDOW_MINUTES <= minutes_to <= BLOCK_WINDOW_MINUTES:
            window_ends = event.event_time + window
            return NewsWindowResult(
                is_blocked=True,
                symbol=symbol,
                affected_currency=event.currency,
                event=event,
                minutes_to_event=round(minutes_to, 1),
                window_ends_at=window_ends,
                reason=(
                    f"{event.title} ({event.currency}) "
                    f"{'in {:.0f} min'.format(minutes_to) if minutes_to > 0 else 'just released'} — "
                    f"trading blocked until {window_ends.strftime('%H:%M')} UTC"
                ),
            )

    return NewsWindowResult(
        is_blocked=False,
        symbol=symbol,
        reason="No high-impact events within ±30 minutes",
    )


async def is_news_window(symbol: str, supabase=None) -> bool:
    """
    Convenience function — used directly by MarketSnapshot population.
    Drop-in for the stub in risk_middleware.py get_market_snapshot().
    """
    result = await check_news_window(symbol, supabase)
    return result.is_blocked


# ─── Upcoming Events ─────────────────────────────────────────────────────────

async def get_upcoming_events(
    currencies: Optional[list[str]] = None,
    hours_ahead: int = 24,
    supabase=None,
) -> list[MacroEvent]:
    """
    Return upcoming high-impact events within the next N hours.
    Filtered by currency if provided.
    """
    events  = await get_cached_events(supabase)
    now     = datetime.now(tz=timezone.utc)
    cutoff  = now + timedelta(hours=hours_ahead)
    watch   = set(currencies) if currencies else MONITORED_CURRENCIES

    return [
        e for e in events
        if e.currency in watch
        and now <= e.event_time <= cutoff
        and e.impact == EventImpact.HIGH
    ]


# ─── Alert Dispatcher ────────────────────────────────────────────────────────

async def dispatch_pre_event_alerts(
    supabase=None,
    notification_service=None,
) -> list[EventAlert]:
    """
    Called by the scheduler after every cache refresh.
    Sends alerts for events happening within the next ALERT_ADVANCE_MINUTES.
    Tracks sent alerts to avoid duplicates.
    """
    events     = await get_cached_events(supabase)
    now        = datetime.now(tz=timezone.utc)
    alert_sent = []

    subscribed_users = await _get_subscribed_users(supabase)

    for event in events:
        # Unique ID for this event (used to deduplicate across refreshes)
        event_key = f"{event.title}_{event.currency}_{event.event_time.isoformat()}"
        if event_key in _alert_sent_ids:
            continue

        delta_minutes = (event.event_time - now).total_seconds() / 60
        if not (0 < delta_minutes <= ALERT_ADVANCE_MINUTES):
            continue

        message = _format_alert_message(event, delta_minutes)

        for user in subscribed_users:
            for channel in [AlertChannel.WHATSAPP, AlertChannel.SMS, AlertChannel.PUSH]:
                alert = EventAlert(
                    user_id=user["user_id"],
                    event=event,
                    channel=channel,
                    message=message,
                )
                sent = await _send_alert(alert, notification_service)
                alert_sent.append(sent)

        _alert_sent_ids.add(event_key)
        logger.info("Alerts dispatched for event: %s (%s)", event.title, event.currency)

    return alert_sent


def _format_alert_message(event: MacroEvent, minutes_to: float) -> str:
    lines = [
        f"⚡ High-impact news in {minutes_to:.0f} minutes",
        f"{event.title} — {event.currency}",
        f"Time: {event.event_time.strftime('%H:%M')} UTC",
    ]
    if event.forecast:
        lines.append(f"Forecast: {event.forecast}")
    if event.previous:
        lines.append(f"Previous: {event.previous}")
    lines.append("Tajir has temporarily blocked trading on affected pairs.")
    return "\n".join(lines)


async def _send_alert(
    alert: EventAlert,
    notification_service=None,
) -> EventAlert:
    """
    Send a single alert via the given channel.

    Replace the stubs below with your existing notification service calls:

    WHATSAPP:
        await notification_service.whatsapp.send(
            to=user_phone, message=alert.message
        )

    SMS (Twilio):
        await notification_service.twilio.messages.create(
            to=user_phone, from_=TWILIO_NUMBER, body=alert.message
        )

    PUSH (Firebase FCM):
        await notification_service.fcm.send(
            token=user_fcm_token,
            title="⚡ News Alert",
            body=alert.message,
        )
    """
    try:
        if alert.channel == AlertChannel.WHATSAPP:
            # await notification_service.whatsapp.send(...)
            pass
        elif alert.channel == AlertChannel.SMS:
            # await notification_service.twilio.messages.create(...)
            pass
        elif alert.channel == AlertChannel.PUSH:
            # await notification_service.fcm.send(...)
            pass

        alert.status  = AlertStatus.SENT
        alert.sent_at = datetime.now(tz=timezone.utc)
        logger.debug("Alert sent: %s → %s via %s", alert.event.title, alert.user_id, alert.channel)

    except Exception as e:
        alert.status = AlertStatus.FAILED
        alert.error  = str(e)
        logger.error("Alert failed: %s via %s — %s", alert.event.title, alert.channel, e)

    return alert


async def _get_subscribed_users(supabase) -> list[dict]:
    """
    Return users who have news alerts enabled.
    STUB — replace with:
        data = supabase.table("user_preferences")
               .select("user_id, phone, fcm_token")
               .eq("news_alerts_enabled", True)
               .execute()
        return data.data
    """
    return []   # Replace with real query