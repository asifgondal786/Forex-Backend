"""
app/services/forex_factory_service.py
Live economic calendar scraper ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÂ¢Ã¢â€šÂ¬Ã‚Â replaces static MacroEventService template.
Scrapes forexfactory.com/calendar.json (public JSON endpoint).
Falls back to static schedule if network is unavailable.
"""
from __future__ import annotations

import asyncio
import logging
import os
from datetime import datetime, timedelta, timezone
from typing import Dict, List, Optional

import httpx

logger = logging.getLogger(__name__)

# ForexFactory public calendar endpoint
_FF_URL = "https://nfs.faireconomy.media/ff_calendar_thisweek.json"
_FF_NEXT_URL = "https://nfs.faireconomy.media/ff_calendar_nextweek.json"
_CACHE_TTL_SECONDS = int(os.getenv("FF_CACHE_TTL_SECONDS", "1800"))  # 30 min

_HIGH_IMPACT_KEYWORDS = {
    "fomc", "federal reserve", "fed rate", "interest rate decision",
    "non-farm", "nonfarm", "nfp", "cpi", "consumer price",
    "gdp", "unemployment", "payroll", "inflation",
    "ecb", "bank of england", "boe", "boj", "bank of japan",
}


class ForexFactoryEvent:
    def __init__(self, raw: Dict) -> None:
        self.title: str = str(raw.get("title") or "")
        # Real FF format: "country" field IS the currency code (e.g. "USD", "GBP")
        country_raw = str(raw.get("country") or "")
        self.country: str = country_raw
        self.currency: str = country_raw if len(country_raw) == 3 else _country_to_currency(country_raw)
        self.impact: str = _normalize_impact(str(raw.get("impact") or ""))
        self.forecast: Optional[str] = raw.get("forecast") or None
        self.previous: Optional[str] = raw.get("previous") or None
        self.actual: Optional[str] = raw.get("actual") or None
        self.category: str = _categorize(self.title)

        # Real FF format: "date" is full ISO datetime e.g. "2026-03-18T14:00:00-04:00"
        raw_date = str(raw.get("date") or "")
        raw_time = str(raw.get("time") or "")
        self.scheduled_at: datetime = _parse_ff_datetime(raw_date, raw_time)

    @property
    def is_high_impact(self) -> bool:
        return self.impact == "high"

    @property
    def is_upcoming(self) -> bool:
        return self.scheduled_at > datetime.now(timezone.utc)

    def to_dict(self) -> Dict:
        return {
            "id": f"ff_{self.currency}_{self.scheduled_at.strftime('%Y%m%d%H%M')}",
            "title": self.title,
            "country": self.country,
            "currency": self.currency,
            "impact": self.impact,
            "category": self.category,
            "scheduled_at": self.scheduled_at.isoformat(),
            "forecast": self.forecast,
            "previous": self.previous,
            "actual": self.actual,
            "is_upcoming": self.is_upcoming,
        }


class ForexFactoryService:
    def __init__(self) -> None:
        self._cache: List[ForexFactoryEvent] = []
        self._cache_time: Optional[datetime] = None
        self._lock = asyncio.Lock()

    async def get_events(
        self,
        hours: int = 48,
        high_impact_only: bool = False,
    ) -> List[Dict]:
        await self._refresh_if_stale()
        now = datetime.now(timezone.utc)
        window_end = now + timedelta(hours=hours)
        window_start = now - timedelta(hours=24)  # include recently released

        results = []
        for event in self._cache:
            if high_impact_only and not event.is_high_impact:
                continue
            if event.scheduled_at < window_start:
                continue
            if event.scheduled_at > window_end:
                continue
            results.append(event.to_dict())

        results.sort(key=lambda e: e["scheduled_at"])
        return results

    async def get_next_high_impact(self) -> Optional[Dict]:
        await self._refresh_if_stale()
        now = datetime.now(timezone.utc)
        upcoming = [
            e for e in self._cache
            if e.is_high_impact and e.scheduled_at > now
        ]
        if not upcoming:
            return None
        upcoming.sort(key=lambda e: e.scheduled_at)
        return upcoming[0].to_dict()

    async def is_shield_active(self, pre_minutes: int = 30) -> Dict:
        next_event = await self.get_next_high_impact()
        now = datetime.now(timezone.utc)

        if not next_event:
            return {
                "shield_active": False,
                "reason": "No high-impact events in calendar",
                "next_event": None,
                "minutes_until": None,
            }

        scheduled = datetime.fromisoformat(
            next_event["scheduled_at"].replace("Z", "+00:00")
        ).astimezone(timezone.utc)

        minutes_until = int((scheduled - now).total_seconds() / 60)
        shield_active = 0 <= minutes_until <= pre_minutes

        return {
            "shield_active": shield_active,
            "reason": (
                f"Shield active ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÂ¢Ã¢â€šÂ¬Ã‚Â {next_event['title']} in {minutes_until}m"
                if shield_active
                else f"Next: {next_event['title']} in {max(minutes_until, 0)}m"
            ),
            "next_event": next_event,
            "minutes_until": max(minutes_until, 0),
        }

    async def _refresh_if_stale(self) -> None:
        async with self._lock:
            now = datetime.now(timezone.utc)
            if (
                self._cache_time is not None
                and (now - self._cache_time).total_seconds() < _CACHE_TTL_SECONDS
            ):
                return
            await self._fetch_and_cache()

    async def _fetch_and_cache(self) -> None:
        events: List[ForexFactoryEvent] = []
        headers = {
            "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36",
            "Accept": "application/json",
            "Referer": "https://www.forexfactory.com/",
        }
        for url in [_FF_URL, _FF_NEXT_URL]:
                try:
                    async with httpx.AsyncClient(timeout=15, headers=headers, follow_redirects=True) as client:
                        resp = await client.get(url)
                        if resp.status_code == 200:
                            data = resp.json()
                            # Handle both {"value": [...]} and [...] formats
                            if isinstance(data, dict) and "value" in data:
                                data = data["value"]
                            if isinstance(data, list):
                                events.extend(
                                    ForexFactoryEvent(item)
                                    for item in data
                                    if isinstance(item, dict)
                                )
                except Exception as exc:
                    logger.warning("ForexFactory fetch failed for %s: %s", url, exc)

        if events:
            self._cache = events
            self._cache_time = datetime.now(timezone.utc)
            logger.info(
                "ForexFactory: cached %d events from live feed", len(events)
            )
        else:
            logger.warning("ForexFactory: live fetch failed, using stale/static cache")
            if not self._cache:
                self._cache = _static_fallback()
                self._cache_time = datetime.now(timezone.utc)


# ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ Helpers ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬

def _normalize_impact(raw: str) -> str:
    r = raw.lower().strip()
    if r in {"high", "3", "red"}:
        return "high"
    if r in {"medium", "moderate", "2", "orange"}:
        return "medium"
    return "low"


def _country_to_currency(country: str) -> str:
    mapping = {
        "usd": "USD", "us": "USD", "united states": "USD",
        "eur": "EUR", "eu": "EUR", "eurozone": "EUR", "euro zone": "EUR",
        "gbp": "GBP", "uk": "GBP", "united kingdom": "GBP",
        "jpy": "JPY", "jp": "JPY", "japan": "JPY",
        "aud": "AUD", "au": "AUD", "australia": "AUD",
        "cad": "CAD", "ca": "CAD", "canada": "CAD",
        "chf": "CHF", "ch": "CHF", "switzerland": "CHF",
        "nzd": "NZD", "nz": "NZD", "new zealand": "NZD",
        "cny": "CNY", "cn": "CNY", "china": "CNY",
    }
    return mapping.get(country.lower().strip(), country.upper()[:3])


def _categorize(title: str) -> str:
    t = title.lower()
    if any(k in t for k in ["fomc", "federal reserve", "fed rate"]):
        return "FOMC"
    if any(k in t for k in ["cpi", "consumer price", "inflation"]):
        return "CPI"
    if any(k in t for k in ["non-farm", "nonfarm", "nfp", "payroll"]):
        return "NFP"
    if "gdp" in t:
        return "GDP"
    if any(k in t for k in ["unemployment", "jobless"]):
        return "EMPLOYMENT"
    if any(k in t for k in ["ecb", "boe", "boj", "bank of"]):
        return "CENTRAL_BANK"
    return "MACRO"


def _parse_ff_datetime(date_str: str, time_str: str) -> datetime:
    try:
        # ForexFactory format: "2026-03-21T00:00:00-05:00" or "03-21-2026"
        if "T" in date_str:
            base = datetime.fromisoformat(date_str).replace(tzinfo=timezone.utc)
        else:
            base = datetime.strptime(date_str, "%m-%d-%Y").replace(
                tzinfo=timezone.utc
            )
        if time_str and time_str.lower() not in {"all day", "tentative", ""}:
            try:
                t = datetime.strptime(time_str.strip(), "%I:%M%p")
                base = base.replace(hour=t.hour, minute=t.minute)
            except ValueError:
                pass
        return base
    except Exception:
        return datetime.now(timezone.utc) + timedelta(hours=24)


def _static_fallback() -> List[ForexFactoryEvent]:
    now = datetime.now(timezone.utc)
    base = now.replace(hour=0, minute=0, second=0, microsecond=0)
    fallbacks = [
        {"title": "FOMC Rate Decision", "country": "US", "impact": "High",
         "date": base.replace(hour=18).isoformat(), "time": ""},
        {"title": "US CPI Release", "country": "US", "impact": "High",
         "date": (base + timedelta(days=3)).replace(hour=12, minute=30).isoformat(), "time": ""},
        {"title": "US Non-Farm Payrolls", "country": "US", "impact": "High",
         "date": (base + timedelta(days=7)).replace(hour=12, minute=30).isoformat(), "time": ""},
    ]
    return [ForexFactoryEvent(f) for f in fallbacks]


forex_factory_service = ForexFactoryService()