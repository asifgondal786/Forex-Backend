"""
app/services/twelve_cache.py
Shared Twelve Data API cache layer.
Provides fetch_price, fetch_timeseries, and fetch_indicator
with in-memory caching to preserve API credits (800/day limit).
"""
from __future__ import annotations

import logging
import os
import time
from typing import Any, Dict, List, Optional

import httpx

logger = logging.getLogger(__name__)

TWELVE_DATA_API_KEY = os.getenv("TWELVE_DATA_API_KEY", "")
BASE_URL = "https://api.twelvedata.com"

# In-memory cache: { cache_key: (timestamp, data) }
_cache: Dict[str, tuple[float, Any]] = {}

PRICE_TTL       = 60        # 1 minute for live prices
TIMESERIES_TTL  = 300       # 5 minutes for OHLC data
INDICATOR_TTL   = 300       # 5 minutes for indicators


def _get(key: str) -> Optional[Any]:
    entry = _cache.get(key)
    if entry and (time.time() - entry[0]) < entry[2]:
        return entry[1]
    return None


def _set(key: str, data: Any, ttl: float) -> None:
    _cache[key] = (time.time(), data, ttl)


async def fetch_price(pairs: List[str]) -> Optional[Dict[str, float]]:
    """
    Fetch latest bid prices for a list of pairs.
    Returns dict: { "EURUSD": 1.0823, ... } or None on failure.
    """
    if not TWELVE_DATA_API_KEY:
        logger.warning("[twelve_cache] TWELVE_DATA_API_KEY not set")
        return None

    symbol_str = ",".join(p.replace("/", "").replace("_", "") for p in pairs)
    cache_key = f"price:{symbol_str}"
    cached = _get(cache_key)
    if cached is not None:
        return cached

    try:
        async with httpx.AsyncClient(timeout=10) as client:
            resp = await client.get(
                f"{BASE_URL}/price",
                params={"symbol": symbol_str, "apikey": TWELVE_DATA_API_KEY},
            )
            resp.raise_for_status()
            raw = resp.json()

        result: Dict[str, float] = {}

        # Single symbol returns {"price": "1.0823"}
        # Multiple symbols returns {"EURUSD": {"price": "1.0823"}, ...}
        if "price" in raw:
            result[pairs[0].replace("/", "").replace("_", "")] = float(raw["price"])
        else:
            for sym, val in raw.items():
                if isinstance(val, dict) and "price" in val:
                    try:
                        result[sym] = float(val["price"])
                    except (ValueError, TypeError):
                        pass

        if result:
            _set(cache_key, result, PRICE_TTL)
            return result

    except Exception as exc:
        logger.error("[twelve_cache] fetch_price error: %s", exc)

    return None


async def fetch_timeseries(
    pair: str,
    interval: str = "1h",
    outputsize: int = 50,
) -> Optional[List[Dict[str, Any]]]:
    """
    Fetch OHLCV timeseries for a pair.
    Returns list of dicts with keys: datetime, open, high, low, close, volume
    Ordered oldest → newest.
    """
    if not TWELVE_DATA_API_KEY:
        logger.warning("[twelve_cache] TWELVE_DATA_API_KEY not set")
        return None

    symbol = pair.replace("/", "").replace("_", "")
    cache_key = f"ts:{symbol}:{interval}:{outputsize}"
    cached = _get(cache_key)
    if cached is not None:
        return cached

    try:
        async with httpx.AsyncClient(timeout=15) as client:
            resp = await client.get(
                f"{BASE_URL}/time_series",
                params={
                    "symbol": symbol,
                    "interval": interval,
                    "outputsize": outputsize,
                    "apikey": TWELVE_DATA_API_KEY,
                },
            )
            resp.raise_for_status()
            raw = resp.json()

        if raw.get("status") == "error":
            logger.error("[twelve_cache] fetch_timeseries API error: %s", raw.get("message"))
            return None

        values = raw.get("values", [])
        if not values:
            return None

        # API returns newest first — reverse to oldest first
        series = list(reversed(values))
        _set(cache_key, series, TIMESERIES_TTL)
        return series

    except Exception as exc:
        logger.error("[twelve_cache] fetch_timeseries error: %s", exc)

    return None


async def fetch_indicator(
    pair: str,
    indicator: str = "rsi",
    interval: str = "1h",
    period: int = 14,
) -> Optional[Dict[str, Any]]:
    """
    Fetch a technical indicator value for a pair.
    Supported: rsi, macd, ema, sma, bbands, stoch, atr
    Returns raw Twelve Data response dict or None on failure.
    """
    if not TWELVE_DATA_API_KEY:
        logger.warning("[twelve_cache] TWELVE_DATA_API_KEY not set")
        return None

    symbol = pair.replace("/", "").replace("_", "")
    cache_key = f"ind:{symbol}:{indicator}:{interval}:{period}"
    cached = _get(cache_key)
    if cached is not None:
        return cached

    params: Dict[str, Any] = {
        "symbol": symbol,
        "interval": interval,
        "apikey": TWELVE_DATA_API_KEY,
    }

    # Map indicator name to endpoint + period param
    endpoint_map = {
        "rsi":    ("rsi",    "time_period"),
        "macd":   ("macd",   "fast_period"),
        "ema":    ("ema",    "time_period"),
        "sma":    ("sma",    "time_period"),
        "bbands": ("bbands", "time_period"),
        "stoch":  ("stoch",  "fast_k_period"),
        "atr":    ("atr",    "time_period"),
    }

    ind_lower = indicator.lower()
    endpoint, period_param = endpoint_map.get(ind_lower, (ind_lower, "time_period"))
    params[period_param] = period

    try:
        async with httpx.AsyncClient(timeout=15) as client:
            resp = await client.get(f"{BASE_URL}/{endpoint}", params=params)
            resp.raise_for_status()
            raw = resp.json()

        if raw.get("status") == "error":
            logger.error("[twelve_cache] fetch_indicator API error: %s", raw.get("message"))
            return None

        _set(cache_key, raw, INDICATOR_TTL)
        return raw

    except Exception as exc:
        logger.error("[twelve_cache] fetch_indicator error: %s", exc)

    return None