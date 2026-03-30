"""
Tajir Macro Event Shield — Forex Factory Scraper
Phase 18

Fetches the Forex Factory economic calendar for the current week,
parses high-impact events for USD, EUR, GBP, JPY, and returns
structured MacroEvent objects.

Forex Factory does not have a public API — we parse the HTML calendar.
The scraper targets the JSON data embedded in the page (FF injects it),
with a BeautifulSoup HTML fallback.

Rate limit: call at most once every 30 minutes (enforced by the scheduler).
"""

from __future__ import annotations

import re
import json
import logging
from datetime import datetime, timezone, timedelta
from typing import Optional
from zoneinfo import ZoneInfo

import httpx
from bs4 import BeautifulSoup

from app.macro_models import MacroEvent, EventImpact

logger = logging.getLogger("macro_shield.scraper")

# ─── Config ───────────────────────────────────────────────────────────────────

MONITORED_CURRENCIES = {"USD", "EUR", "GBP", "JPY"}
MONITORED_IMPACT     = {EventImpact.HIGH}           # only high-impact events trigger the shield
FF_BASE_URL          = "https://www.forexfactory.com/calendar"
REQUEST_TIMEOUT      = 15   # seconds

HEADERS = {
    "User-Agent": (
        "Mozilla/5.0 (Windows NT 10.0; Win64; x64) "
        "AppleWebKit/537.36 (KHTML, like Gecko) "
        "Chrome/124.0.0.0 Safari/537.36"
    ),
    "Accept-Language": "en-US,en;q=0.9",
    "Accept": "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8",
}

# Impact label mapping from FF HTML classes → our enum
FF_IMPACT_MAP = {
    "icon--ff-impact-red":    EventImpact.HIGH,
    "icon--ff-impact-ora":    EventImpact.MEDIUM,
    "icon--ff-impact-yel":    EventImpact.LOW,
    "high":                   EventImpact.HIGH,
    "medium":                 EventImpact.MEDIUM,
    "low":                    EventImpact.LOW,
}


# ─── Main Fetch ───────────────────────────────────────────────────────────────

async def fetch_calendar_events(
    days_ahead: int = 7,
) -> list[MacroEvent]:
    """
    Fetch and parse the Forex Factory calendar.
    Returns filtered high-impact events for monitored currencies.
    Falls back to empty list on any network or parse error (never raises).
    """
    try:
        raw_html = await _fetch_ff_page()
    except Exception as e:
        logger.error("Failed to fetch Forex Factory calendar: %s", e)
        return []

    try:
        events = _parse_ff_html(raw_html)
    except Exception as e:
        logger.error("Failed to parse Forex Factory calendar: %s", e)
        return []

    now = datetime.now(tz=timezone.utc)
    cutoff = now + timedelta(days=days_ahead)

    filtered = [
        e for e in events
        if e.currency in MONITORED_CURRENCIES
        and e.impact in MONITORED_IMPACT
        and now <= e.event_time <= cutoff
    ]

    logger.info(
        "FF calendar: %d total events → %d high-impact monitored currency events",
        len(events), len(filtered),
    )
    return filtered


# ─── HTTP Fetch ───────────────────────────────────────────────────────────────

async def _fetch_ff_page() -> str:
    async with httpx.AsyncClient(timeout=REQUEST_TIMEOUT, follow_redirects=True) as client:
        resp = await client.get(FF_BASE_URL, headers=HEADERS)
        resp.raise_for_status()
        return resp.text


# ─── Parser ───────────────────────────────────────────────────────────────────

def _parse_ff_html(html: str) -> list[MacroEvent]:
    """
    Parse Forex Factory calendar HTML.

    FF embeds calendar data as a JSON blob in a <script> tag.
    We try to extract that first (faster, more reliable).
    If it fails, we fall back to table row parsing.
    """
    events = _try_parse_json_embed(html)
    if events:
        return events
    return _parse_table(html)


def _try_parse_json_embed(html: str) -> list[MacroEvent]:
    """
    FF sometimes injects: window.calendarComponentStates = {...}
    or a similar JSON blob. Try to extract it.
    """
    pattern = re.search(r'calendarComponentStates\s*=\s*(\[.*?\]);', html, re.DOTALL)
    if not pattern:
        return []

    try:
        raw = json.loads(pattern.group(1))
    except json.JSONDecodeError:
        return []

    events: list[MacroEvent] = []
    for item in raw:
        try:
            event_time = _parse_ff_datetime(item.get("date", ""), item.get("time", ""))
            if not event_time:
                continue

            impact_raw = item.get("impact", "").lower()
            impact = FF_IMPACT_MAP.get(impact_raw, EventImpact.LOW)

            events.append(MacroEvent(
                title=item.get("name", "Unknown"),
                currency=item.get("currency", "").upper(),
                impact=impact,
                event_time=event_time,
                forecast=item.get("forecast") or None,
                previous=item.get("previous") or None,
                actual=item.get("actual") or None,
                source="forexfactory",
                fetched_at=datetime.now(tz=timezone.utc),
            ))
        except Exception:
            continue

    return events


def _parse_table(html: str) -> list[MacroEvent]:
    """
    Fallback: parse the <table class="calendar__table"> directly.
    FF renders a standard HTML table when JS is not available.
    """
    soup = BeautifulSoup(html, "html.parser")
    table = soup.find("table", class_=re.compile(r"calendar"))
    if not table:
        logger.warning("Could not find calendar table in FF HTML")
        return []

    events: list[MacroEvent] = []
    current_date_str = ""
    current_time_str = ""

    for row in table.find_all("tr", class_=re.compile(r"calendar__row")):

        # Date cell — FF only puts date on first row of each day
        date_cell = row.find("td", class_=re.compile(r"calendar__date"))
        if date_cell and date_cell.get_text(strip=True):
            current_date_str = date_cell.get_text(strip=True)

        # Time cell
        time_cell = row.find("td", class_=re.compile(r"calendar__time"))
        if time_cell and time_cell.get_text(strip=True):
            current_time_str = time_cell.get_text(strip=True)

        # Currency
        currency_cell = row.find("td", class_=re.compile(r"calendar__currency"))
        if not currency_cell:
            continue
        currency = currency_cell.get_text(strip=True).upper()

        # Impact
        impact_cell = row.find("td", class_=re.compile(r"calendar__impact"))
        impact = EventImpact.LOW
        if impact_cell:
            span = impact_cell.find("span")
            if span:
                classes = " ".join(span.get("class", []))
                for key, val in FF_IMPACT_MAP.items():
                    if key in classes:
                        impact = val
                        break

        # Title
        title_cell = row.find("td", class_=re.compile(r"calendar__event"))
        title = title_cell.get_text(strip=True) if title_cell else "Unknown"

        # Forecast / Previous / Actual
        forecast = _cell_text(row, "calendar__forecast")
        previous = _cell_text(row, "calendar__previous")
        actual   = _cell_text(row, "calendar__actual")

        event_time = _parse_ff_datetime(current_date_str, current_time_str)
        if not event_time:
            continue

        events.append(MacroEvent(
            title=title,
            currency=currency,
            impact=impact,
            event_time=event_time,
            forecast=forecast,
            previous=previous,
            actual=actual,
            source="forexfactory",
            fetched_at=datetime.now(tz=timezone.utc),
        ))

    return events


# ─── Helpers ──────────────────────────────────────────────────────────────────

def _cell_text(row, class_fragment: str) -> Optional[str]:
    cell = row.find("td", class_=re.compile(class_fragment))
    if cell:
        text = cell.get_text(strip=True)
        return text if text not in ("", "—", "-") else None
    return None


def _parse_ff_datetime(date_str: str, time_str: str) -> Optional[datetime]:
    """
    Parse FF date + time strings into UTC datetime.
    FF displays times in US Eastern (ET), which is UTC-5 (EST) or UTC-4 (EDT).
    We convert to UTC.

    Example inputs:
        date_str = "Mon Jan 13"  or "Jan 13"
        time_str = "8:30am"     or "All Day" or ""
    """
    if not date_str:
        return None

    # Normalise date — strip day name if present
    date_clean = re.sub(r'^[A-Za-z]{3}\s+', '', date_str.strip())  # "Mon Jan 13" → "Jan 13"
    year = datetime.now(tz=timezone.utc).year

    # Handle "All Day" or missing times — use market open 00:00 ET
    if not time_str or time_str.lower() in ("all day", "tentative", ""):
        time_clean = "12:00am"
    else:
        time_clean = time_str.strip().lower()

    try:
        et_tz = ZoneInfo("America/New_York")
        dt_str = f"{date_clean} {year} {time_clean}"
        dt_et = datetime.strptime(dt_str, "%b %d %Y %I:%M%p").replace(tzinfo=et_tz)
        return dt_et.astimezone(timezone.utc)
    except (ValueError, KeyError):
        return None


# ─── Currency pair → relevant currencies ──────────────────────────────────────

def currencies_for_symbol(symbol: str) -> list[str]:
    """
    Extract the two currencies from a forex symbol.
    "EURUSD" → ["EUR", "USD"]
    "GBPJPY" → ["GBP", "JPY"]
    """
    symbol = symbol.upper().replace("/", "").replace("_", "")
    if len(symbol) == 6:
        return [symbol[:3], symbol[3:]]
    return []