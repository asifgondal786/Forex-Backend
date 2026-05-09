import os
import httpx
import logging
from datetime import datetime, timezone, timedelta
from typing import Optional

from dotenv import load_dotenv
load_dotenv()

logger = logging.getLogger(__name__)

# ── Forex Factory public JSON feed (no key required) ──────────────────────────
_FF_URL = "https://nfs.faireconomy.media/ff_calendar_thisweek.json"
_FF_NEXT_URL = "https://nfs.faireconomy.media/ff_calendar_nextweek.json"

_cache: dict = {}
_cache_time: dict = {}
CACHE_TTL = 3600  # 1 hour — FF updates ~every hour


def _is_cached(key: str) -> bool:
    if key not in _cache_time:
        return False
    age = (datetime.now(timezone.utc) - _cache_time[key]).total_seconds()
    return age < CACHE_TTL


def _parse_ff_date(date_str: str) -> Optional[datetime]:
    """
    FF JSON dates look like: '2026-05-09T12:30:00-04:00'
    Parse to UTC datetime.
    """
    if not date_str:
        return None
    try:
        # Python 3.11+ handles %z with colon; use fromisoformat for safety
        dt = datetime.fromisoformat(date_str)
        return dt.astimezone(timezone.utc)
    except Exception:
        return None


def _normalize(evt: dict) -> dict:
    """
    Normalize FF JSON event to the same shape the rest of the app expects:
      Name, Currency, Impact, Date (YYYY.MM.DD HH:MM:SS), Category, Actual, Forecast, Previous
    """
    raw_date = evt.get("date", "")
    dt_utc = _parse_ff_date(raw_date)
    date_fmt = dt_utc.strftime("%Y.%m.%d %H:%M:%S") if dt_utc else raw_date

    impact_map = {"High": "High", "Medium": "Medium", "Low": "Low", "Holiday": "None"}
    raw_impact = evt.get("impact", "")
    impact = impact_map.get(raw_impact, raw_impact)

    return {
        "Name":      evt.get("title", ""),
        "Currency":  evt.get("country", "").upper(),
        "Impact":    impact,
        "Date":      date_fmt,
        "Category":  "Economy Report",
        "Actual":    evt.get("actual", ""),
        "Forecast":  evt.get("forecast", ""),
        "Previous":  evt.get("previous", ""),
        "_dt_utc":   dt_utc,
    }


async def _fetch_ff(url: str) -> list[dict]:
    """Fetch and normalize one FF JSON feed URL."""
    try:
        async with httpx.AsyncClient(timeout=10.0, follow_redirects=True) as client:
            r = await client.get(
                url,
                headers={"User-Agent": "Mozilla/5.0 (compatible; TajirBot/1.0)"},
            )
            if r.status_code == 404:
                logger.debug("FF feed not yet available (404): %s", url)
                return []
            r.raise_for_status()
            raw = r.json()
            if not isinstance(raw, list):
                logger.warning("FF feed returned non-list: %s", type(raw))
                return []
            return [_normalize(e) for e in raw]
    except Exception as e:
        logger.error("FF feed fetch failed [%s]: %s", url, e)
        return []


async def _get_all_events() -> list[dict]:
    """Return this-week + next-week events, merged and cached."""
    cache_key = "all_events"
    if _is_cached(cache_key):
        return _cache[cache_key]

    this_week, next_week = await __import__("asyncio").gather(
        _fetch_ff(_FF_URL),
        _fetch_ff(_FF_NEXT_URL),
    )
    events = this_week + next_week
    _cache[cache_key] = events
    _cache_time[cache_key] = datetime.now(timezone.utc)
    logger.info("FF: loaded %d events (this week: %d, next week: %d)",
                len(events), len(this_week), len(next_week))
    return events


# ── Public API (same signatures as before) ────────────────────────────────────

async def get_today_events(
    currency: str = None,
    impact: str = None,
) -> list[dict]:
    cache_key = f"today_{currency}_{impact}"
    if _is_cached(cache_key):
        return _cache[cache_key]

    all_events = await _get_all_events()
    now = datetime.now(timezone.utc)
    today_start = now.replace(hour=0, minute=0, second=0, microsecond=0)
    today_end   = today_start + timedelta(days=1)

    events = [
        e for e in all_events
        if e.get("_dt_utc") and today_start <= e["_dt_utc"] < today_end
    ]
    if currency:
        events = [e for e in events if e.get("Currency", "").upper() == currency.upper()]
    if impact:
        events = [e for e in events if e.get("Impact", "").lower() == impact.lower()]

    events = sorted(events, key=lambda x: x.get("_dt_utc") or now)
    _cache[cache_key] = events
    _cache_time[cache_key] = datetime.now(timezone.utc)
    return events


async def get_week_events(
    currency: str = None,
    impact: str = None,
) -> list[dict]:
    cache_key = f"week_{currency}_{impact}"
    if _is_cached(cache_key):
        return _cache[cache_key]

    all_events = await _get_all_events()
    events = list(all_events)
    if currency:
        events = [e for e in events if e.get("Currency", "").upper() == currency.upper()]
    if impact:
        events = [e for e in events if e.get("Impact", "").lower() == impact.lower()]

    events = sorted(events, key=lambda x: x.get("_dt_utc") or datetime.now(timezone.utc))
    _cache[cache_key] = events
    _cache_time[cache_key] = datetime.now(timezone.utc)
    return events


async def get_high_impact_today() -> list[dict]:
    return await get_today_events(impact="High")


async def get_upcoming_events(hours_ahead: int = 8) -> list[dict]:
    all_events = await _get_all_events()
    now = datetime.now(timezone.utc)
    upcoming = []
    for evt in all_events:
        dt = evt.get("_dt_utc")
        if not dt:
            continue
        diff_hours = (dt - now).total_seconds() / 3600
        if 0 <= diff_hours <= hours_ahead:
            upcoming.append({**evt, "_hours_ahead": round(diff_hours, 1)})
    return sorted(upcoming, key=lambda x: x.get("_hours_ahead", 99))


async def is_news_shield_active(pre_minutes: int = 30) -> dict:
    events = await get_today_events(impact="High")
    now = datetime.now(timezone.utc)
    for evt in events:
        dt = evt.get("_dt_utc")
        if not dt:
            continue
        diff_minutes = (dt - now).total_seconds() / 60
        if -5 <= diff_minutes <= pre_minutes:
            return {
                "shield_active": True,
                "event_name":    evt.get("Name", "High Impact Event"),
                "currency":      evt.get("Currency", ""),
                "impact":        evt.get("Impact", "High"),
                "minutes_until": round(diff_minutes, 1),
                "event_time":    evt.get("Date", ""),
            }
    return {"shield_active": False, "event_name": None, "minutes_until": None}


def format_for_ai_context(events: list[dict], max_events: int = 5) -> str:
    if not events:
        return "No major calendar events in the next 8 hours."
    lines = []
    for evt in events[:max_events]:
        impact   = evt.get("Impact", "").upper()
        name     = evt.get("Name", "Unknown")
        currency = evt.get("Currency", "")
        date_str = evt.get("Date", "")
        hours    = evt.get("_hours_ahead", "")
        hours_str = f" (in {hours}h)" if hours != "" else ""
        actual   = evt.get("Actual", "")
        forecast = evt.get("Forecast", "")
        extra = ""
        if actual:
            extra = f" Actual:{actual}"
        elif forecast:
            extra = f" Forecast:{forecast}"
        lines.append(f"  [{impact}] {currency} - {name}{hours_str} @ {date_str}{extra}")
    return "\n".join(lines)


# ── Singleton service (same interface as before) ───────────────────────────────

class ForexFactoryService:
    async def get_events(self, hours: int = 48, high_impact_only: bool = False) -> list[dict]:
        if high_impact_only:
            return await get_upcoming_events(hours_ahead=hours)
        return await get_week_events()

    async def is_shield_active(self, pre_minutes: int = 30) -> dict:
        return await is_news_shield_active(pre_minutes)

    async def get_next_high_impact(self) -> dict:
        events = await get_high_impact_today()
        now = datetime.now(timezone.utc)
        for evt in sorted(events, key=lambda x: x.get("_dt_utc") or now):
            if evt.get("_dt_utc") and evt["_dt_utc"] > now:
                return evt
        return {}

    async def get_upcoming_events(self, hours_ahead: int = 8) -> list[dict]:
        return await get_upcoming_events(hours_ahead)

    @property
    def _cache(self):
        return _cache


forex_factory_service = ForexFactoryService()