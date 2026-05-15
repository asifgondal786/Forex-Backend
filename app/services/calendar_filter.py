import logging
import os
from datetime import datetime, timezone, timedelta
from typing import Optional
import httpx

logger = logging.getLogger("app.calendar_filter")

FINNHUB_API_KEY = os.getenv("FINNHUB_API_KEY", "")
FINNHUB_URL = "https://finnhub.io/api/v1/calendar/economic"

# How many minutes before/after a high-impact event to block trading
BLACKOUT_MINUTES_BEFORE = 30
BLACKOUT_MINUTES_AFTER = 30

# Only block on these impact levels
BLOCK_IMPACT_LEVELS = {"high"}


async def _fetch_events(date_str: str) -> list:
    """Fetch economic calendar events for a given date (YYYY-MM-DD)."""
    if not FINNHUB_API_KEY:
        logger.warning("FINNHUB_API_KEY not set — calendar filter disabled")
        return []
    try:
        async with httpx.AsyncClient(timeout=10.0) as client:
            resp = await client.get(
                FINNHUB_URL,
                params={
                    "from": date_str,
                    "to": date_str,
                    "token": FINNHUB_API_KEY,
                },
            )
            resp.raise_for_status()
            data = resp.json()
            return data.get("economicCalendar", [])
    except Exception as e:
        logger.warning("Failed to fetch Finnhub calendar: %s", e)
        return []


async def is_news_blackout(pair: Optional[str] = None) -> bool:
    """
    Returns True if current time is within a blackout window around
    a high-impact economic event relevant to the given pair.

    Usage:
        if await is_news_blackout(pair="EURUSD"):
            skip the trade

    If pair is None, checks for ANY high-impact event globally.
    """
    now = datetime.now(timezone.utc)
    date_str = now.strftime("%Y-%m-%d")

    events = await _fetch_events(date_str)
    if not events:
        return False

    # Map pair to relevant currencies
    relevant_currencies = _pair_to_currencies(pair)

    for event in events:
        # Check impact level
        impact = (event.get("impact") or "").lower()
        if impact not in BLOCK_IMPACT_LEVELS:
            continue

        # Check currency relevance
        event_currency = (event.get("currency") or "").upper()
        if relevant_currencies and event_currency not in relevant_currencies:
            continue

        # Parse event time
        event_time = _parse_event_time(event)
        if event_time is None:
            continue

        # Check if we are in the blackout window
        window_start = event_time - timedelta(minutes=BLACKOUT_MINUTES_BEFORE)
        window_end = event_time + timedelta(minutes=BLACKOUT_MINUTES_AFTER)

        if window_start <= now <= window_end:
            logger.info(
                "News blackout active | event=%s currency=%s time=%s pair=%s",
                event.get("event", "unknown"),
                event_currency,
                event_time.isoformat(),
                pair,
            )
            return True

    return False


def _pair_to_currencies(pair: Optional[str]) -> set:
    """Extract the two currencies from a pair string like EURUSD or EUR_USD."""
    if not pair:
        return set()
    clean = pair.replace("_", "").replace("/", "").upper()
    if len(clean) >= 6:
        return {clean[:3], clean[3:6]}
    return set()


def _parse_event_time(event: dict) -> Optional[datetime]:
    """Parse event time from Finnhub response."""
    # Finnhub returns 'time' as Unix timestamp or ISO string
    raw = event.get("time")
    if raw is None:
        return None
    try:
        if isinstance(raw, (int, float)):
            return datetime.fromtimestamp(raw, tz=timezone.utc)
        # Try ISO string
        return datetime.fromisoformat(str(raw).replace("Z", "+00:00"))
    except Exception:
        return None


async def get_upcoming_events(pair: Optional[str] = None, hours_ahead: int = 24) -> list:
    """
    Returns list of upcoming high-impact events for the pair within hours_ahead.
    Useful for the frontend to show warnings.
    """
    now = datetime.now(timezone.utc)
    date_str = now.strftime("%Y-%m-%d")
    events = await _fetch_events(date_str)

    relevant_currencies = _pair_to_currencies(pair)
    upcoming = []

    for event in events:
        impact = (event.get("impact") or "").lower()
        if impact not in BLOCK_IMPACT_LEVELS:
            continue

        event_currency = (event.get("currency") or "").upper()
        if relevant_currencies and event_currency not in relevant_currencies:
            continue

        event_time = _parse_event_time(event)
        if event_time is None:
            continue

        if now <= event_time <= now + timedelta(hours=hours_ahead):
            upcoming.append({
                "event": event.get("event", "Unknown"),
                "currency": event_currency,
                "time_utc": event_time.isoformat(),
                "impact": impact,
                "minutes_until": int((event_time - now).total_seconds() / 60),
            })

    upcoming.sort(key=lambda x: x["minutes_until"])
    return upcoming
