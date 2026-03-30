"""
Tajir Phase 18 â€” Macro Event Shield Unit Tests
Run with: pytest test_macro_shield.py -v
"""

import sys
sys.path.insert(0, ".")

import pytest
from datetime import datetime, timezone, timedelta
from unittest.mock import AsyncMock, patch

from macro_models import MacroEvent, EventImpact, NewsWindowResult
from macro_scraper import currencies_for_symbol, _parse_ff_datetime
from macro_shield import check_news_window, get_upcoming_events


# â”€â”€â”€ Fixtures â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

def make_event(
    title="Non-Farm Payrolls",
    currency="USD",
    impact=EventImpact.HIGH,
    minutes_from_now: float = 20.0,
) -> MacroEvent:
    return MacroEvent(
        title=title,
        currency=currency,
        impact=impact,
        event_time=datetime.now(tz=timezone.utc) + timedelta(minutes=minutes_from_now),
        forecast="200K",
        previous="180K",
        source="forexfactory",
        fetched_at=datetime.now(tz=timezone.utc),
    )


# â”€â”€â”€ Scraper Helper Tests â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

class TestCurrenciesForSymbol:

    def test_eurusd(self):
        assert set(currencies_for_symbol("EURUSD")) == {"EUR", "USD"}

    def test_gbpjpy(self):
        assert set(currencies_for_symbol("GBPJPY")) == {"GBP", "JPY"}

    def test_with_slash(self):
        assert set(currencies_for_symbol("EUR/USD")) == {"EUR", "USD"}

    def test_unknown_symbol(self):
        result = currencies_for_symbol("XAUUSD")
        assert len(result) == 2   # still splits, XAU not in monitored set

    def test_invalid_symbol(self):
        result = currencies_for_symbol("XY")
        assert result == []


class TestDatetimeParser:

    def test_standard_format(self):
        dt = _parse_ff_datetime("Jan 13", "8:30am")
        assert dt is not None
        assert dt.tzinfo is not None

    def test_all_day(self):
        dt = _parse_ff_datetime("Jan 13", "All Day")
        assert dt is not None

    def test_empty_time(self):
        dt = _parse_ff_datetime("Jan 13", "")
        assert dt is not None

    def test_missing_date(self):
        dt = _parse_ff_datetime("", "8:30am")
        assert dt is None

    def test_with_day_name(self):
        dt = _parse_ff_datetime("Mon Jan 13", "2:00pm")
        assert dt is not None


# â”€â”€â”€ Window Checker Tests â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

class TestCheckNewsWindow:

    @pytest.mark.asyncio
    async def test_blocked_when_event_in_window(self):
        event = make_event(currency="USD", minutes_from_now=15)
        with patch("macro_shield.get_cached_events", AsyncMock(return_value=[event])):
            result = await check_news_window("EURUSD")
        assert result.is_blocked is True
        assert result.affected_currency == "USD"
        assert result.event is not None

    @pytest.mark.asyncio
    async def test_not_blocked_when_event_far_away(self):
        event = make_event(currency="USD", minutes_from_now=90)
        with patch("macro_shield.get_cached_events", AsyncMock(return_value=[event])):
            result = await check_news_window("EURUSD")
        assert result.is_blocked is False

    @pytest.mark.asyncio
    async def test_not_blocked_when_event_past_window(self):
        event = make_event(currency="USD", minutes_from_now=-45)  # 45 min ago
        with patch("macro_shield.get_cached_events", AsyncMock(return_value=[event])):
            result = await check_news_window("EURUSD")
        assert result.is_blocked is False

    @pytest.mark.asyncio
    async def test_blocked_for_either_currency(self):
        # GBP event should block GBPUSD
        event = make_event(currency="GBP", minutes_from_now=10)
        with patch("macro_shield.get_cached_events", AsyncMock(return_value=[event])):
            result = await check_news_window("GBPUSD")
        assert result.is_blocked is True

    @pytest.mark.asyncio
    async def test_not_blocked_for_unrelated_currency(self):
        # JPY event should NOT block EURUSD
        event = make_event(currency="JPY", minutes_from_now=10)
        with patch("macro_shield.get_cached_events", AsyncMock(return_value=[event])):
            result = await check_news_window("EURUSD")
        assert result.is_blocked is False

    @pytest.mark.asyncio
    async def test_medium_impact_does_not_block(self):
        event = make_event(currency="USD", impact=EventImpact.MEDIUM, minutes_from_now=10)
        with patch("macro_shield.get_cached_events", AsyncMock(return_value=[event])):
            result = await check_news_window("EURUSD")
        assert result.is_blocked is False

    @pytest.mark.asyncio
    async def test_reason_populated_on_block(self):
        event = make_event(currency="USD", minutes_from_now=20)
        with patch("macro_shield.get_cached_events", AsyncMock(return_value=[event])):
            result = await check_news_window("EURUSD")
        assert len(result.reason) > 10

    @pytest.mark.asyncio
    async def test_window_ends_at_populated(self):
        event = make_event(currency="USD", minutes_from_now=10)
        with patch("macro_shield.get_cached_events", AsyncMock(return_value=[event])):
            result = await check_news_window("EURUSD")
        assert result.window_ends_at is not None
        assert result.window_ends_at > event.event_time


# â”€â”€â”€ Upcoming Events Tests â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

class TestGetUpcomingEvents:

    @pytest.mark.asyncio
    async def test_returns_future_events_only(self):
        past   = make_event(currency="USD", minutes_from_now=-60)
        future = make_event(currency="USD", minutes_from_now=120)
        with patch("macro_shield.get_cached_events", AsyncMock(return_value=[past, future])):
            events = await get_upcoming_events(currencies=["USD"], hours_ahead=24)
        assert future in events
        assert past not in events

    @pytest.mark.asyncio
    async def test_filters_by_currency(self):
        usd = make_event(currency="USD", minutes_from_now=60)
        eur = make_event(currency="EUR", minutes_from_now=60)
        with patch("macro_shield.get_cached_events", AsyncMock(return_value=[usd, eur])):
            events = await get_upcoming_events(currencies=["USD"], hours_ahead=24)
        assert usd in events
        assert eur not in events

    @pytest.mark.asyncio
    async def test_respects_hours_ahead(self):
        soon = make_event(currency="USD", minutes_from_now=30)
        far  = make_event(currency="USD", minutes_from_now=180)   # 3 hours
        with patch("macro_shield.get_cached_events", AsyncMock(return_value=[soon, far])):
            events = await get_upcoming_events(currencies=["USD"], hours_ahead=2)
        assert soon in events
        assert far not in events