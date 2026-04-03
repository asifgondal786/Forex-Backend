# =============================================================
# D:\Tajir\Backend\app\services\forex_data_service.py
#
# Forex Data Service — 8-API fallback chain
# Priority order:
#   1. Twelve Data       (TWELVE_DATA_API_KEY)
#   2. FCS API           (FCS_API_KEY)
#   3. ForexRatesAPI     (FOREXRATEAPI_API_KEY)
#   4. ExchangeRatesAPI  (EXCHANGERATESAPI_API_KEY)
#   5. iTick             (ITICK_API_KEY)
#   6. Finnhub           (FINNHUB_KEY)
#   7. MarketAux news    (MARKETAUX_NEWS_ENDPOINT)
#   8. GDELT sentiment   (GDELT_SENTIMENT_ENDPOINT)
#
# All cache TTLs respect .env values:
#   FOREX_RATES_MIN_FETCH_INTERVAL_SECONDS
#   FOREX_FORECAST_CACHE_TTL_SECONDS
#   FOREX_NEWS_CACHE_TTL_SECONDS
#   FOREX_SENTIMENT_CACHE_TTL_SECONDS
# =============================================================

from __future__ import annotations

import asyncio
import logging
import os
import time
from typing import Any

import httpx
from tenacity import (
    retry,
    retry_if_exception_type,
    stop_after_attempt,
    wait_exponential,
)

logger = logging.getLogger("app.services.forex_data_service")

# ── .env keys ─────────────────────────────────────────────────────────────────
_TWELVE_DATA_KEY     = os.getenv("TWELVE_DATA_API_KEY", "")
_FCS_KEY             = os.getenv("FCS_API_KEY", "")
_FOREXRATE_KEY       = os.getenv("FOREXRATEAPI_API_KEY", "")
_EXCHANGERATES_KEY   = os.getenv("EXCHANGERATESAPI_API_KEY", "")
_ITICK_KEY           = os.getenv("ITICK_API_KEY", "")
_FINNHUB_KEY         = os.getenv("FINNHUB_KEY", "")
_MARKETAUX_ENDPOINT  = os.getenv("MARKETAUX_NEWS_ENDPOINT", "")
_GDELT_ENDPOINT      = os.getenv("GDELT_SENTIMENT_ENDPOINT", "")

# ── Cache TTLs from .env ──────────────────────────────────────────────────────
_RATES_TTL       = int(os.getenv("FOREX_RATES_MIN_FETCH_INTERVAL_SECONDS", "3"))
_FORECAST_TTL    = int(os.getenv("FOREX_FORECAST_CACHE_TTL_SECONDS", "20"))
_NEWS_TTL        = int(os.getenv("FOREX_NEWS_CACHE_TTL_SECONDS", "30"))
_SENTIMENT_TTL   = int(os.getenv("FOREX_SENTIMENT_CACHE_TTL_SECONDS", "15"))

# ── Supported pairs ───────────────────────────────────────────────────────────
_DEFAULT_PAIRS = [
    "EUR/USD", "GBP/USD", "USD/JPY", "AUD/USD",
    "USD/CAD", "USD/CHF", "NZD/USD", "USD/PKR",
]

# ── Simple in-memory TTL cache ────────────────────────────────────────────────
_cache: dict[str, tuple[Any, float]] = {}


def _cache_get(key: str) -> Any | None:
    entry = _cache.get(key)
    if entry is None:
        return None
    value, expires_at = entry
    if time.monotonic() > expires_at:
        del _cache[key]
        return None
    return value


def _cache_set(key: str, value: Any, ttl: int) -> None:
    _cache[key] = (value, time.monotonic() + ttl)


# ── Shared HTTP client ────────────────────────────────────────────────────────
_http: httpx.AsyncClient | None = None


def _client() -> httpx.AsyncClient:
    global _http
    if _http is None or _http.is_closed:
        _http = httpx.AsyncClient(timeout=10.0)
    return _http


async def close() -> None:
    global _http
    if _http and not _http.is_closed:
        await _http.aclose()
        _http = None


# ─────────────────────────────────────────────────────────────────────────────
# RATES — 5-provider fallback chain
# ─────────────────────────────────────────────────────────────────────────────

async def _rates_twelve_data(pairs: list[str]) -> dict[str, float] | None:
    if not _TWELVE_DATA_KEY:
        return None
    try:
        symbols = ",".join(p.replace("/", "") for p in pairs)
        r = await _client().get(
            "https://api.twelvedata.com/price",
            params={"symbol": symbols, "apikey": _TWELVE_DATA_KEY},
        )
        r.raise_for_status()
        data = r.json()
        result: dict[str, float] = {}
        # Twelve Data returns single object if one symbol, list otherwise
        if isinstance(data, dict) and "price" in data:
            # Single pair
            result[pairs[0]] = float(data["price"])
        else:
            for pair in pairs:
                sym = pair.replace("/", "")
                if sym in data and "price" in data[sym]:
                    result[pair] = float(data[sym]["price"])
        return result if result else None
    except Exception as exc:
        logger.warning("Twelve Data rates failed: %s", exc)
        return None


async def _rates_fcs(pairs: list[str]) -> dict[str, float] | None:
    if not _FCS_KEY:
        return None
    try:
        result: dict[str, float] = {}
        for pair in pairs:
            symbol = pair.replace("/", "_")
            r = await _client().get(
                "https://fcsapi.com/api-v3/forex/latest",
                params={"symbol": symbol, "access_key": _FCS_KEY},
            )
            r.raise_for_status()
            data = r.json()
            if data.get("status") and data.get("response"):
                price = data["response"][0].get("c")
                if price:
                    result[pair] = float(price)
        return result if result else None
    except Exception as exc:
        logger.warning("FCS rates failed: %s", exc)
        return None


async def _rates_forexrateapi(base: str = "USD") -> dict[str, float] | None:
    if not _FOREXRATE_KEY:
        return None
    try:
        r = await _client().get(
            f"https://v6.exchangerate-api.com/v6/{_FOREXRATE_KEY}/latest/{base}"
        )
        r.raise_for_status()
        data = r.json()
        if data.get("result") == "success":
            return data.get("conversion_rates", {})
        return None
    except Exception as exc:
        logger.warning("ForexRatesAPI failed: %s", exc)
        return None


async def _rates_exchangeratesapi(base: str = "USD") -> dict[str, float] | None:
    if not _EXCHANGERATES_KEY:
        return None
    try:
        r = await _client().get(
            "https://api.exchangeratesapi.io/v1/latest",
            params={"access_key": _EXCHANGERATES_KEY, "base": base},
        )
        r.raise_for_status()
        data = r.json()
        if data.get("success"):
            return data.get("rates", {})
        return None
    except Exception as exc:
        logger.warning("ExchangeRatesAPI failed: %s", exc)
        return None


async def _rates_itick(pairs: list[str]) -> dict[str, float] | None:
    if not _ITICK_KEY:
        return None
    try:
        result: dict[str, float] = {}
        for pair in pairs:
            symbol = pair.replace("/", "")
            r = await _client().get(
                f"https://api.itick.org/forex/quote",
                params={"token": _ITICK_KEY, "symbol": symbol},
            )
            r.raise_for_status()
            data = r.json()
            price = (data.get("data") or {}).get("c") or (data.get("data") or {}).get("ask")
            if price:
                result[pair] = float(price)
        return result if result else None
    except Exception as exc:
        logger.warning("iTick rates failed: %s", exc)
        return None


async def get_rates(pairs: list[str] | None = None) -> dict[str, Any]:
    """
    Get live forex rates with 5-provider fallback chain.
    Returns: {"rates": {"EUR/USD": 1.0851, ...}, "source": "twelve_data", "cached": bool}
    """
    pairs = pairs or _DEFAULT_PAIRS
    cache_key = f"rates:{','.join(sorted(pairs))}"
    cached = _cache_get(cache_key)
    if cached:
        return {**cached, "cached": True}

    # Fallback chain
    providers = [
        ("twelve_data",    _rates_twelve_data(pairs)),
        ("fcs",            _rates_fcs(pairs)),
        ("itick",          _rates_itick(pairs)),
    ]

    rates: dict[str, float] | None = None
    source = "unavailable"

    for name, coro in providers:
        try:
            result = await coro
            if result:
                rates = result
                source = name
                break
        except Exception:
            continue

    # If pair-level lookups failed, try base-currency providers
    if not rates:
        for name, coro in [
            ("forexratesapi",   _rates_forexrateapi("USD")),
            ("exchangeratesapi", _rates_exchangeratesapi("USD")),
        ]:
            try:
                all_rates = await coro
                if all_rates:
                    # Convert to pair format
                    rates = {}
                    for pair in pairs:
                        base, quote = pair.split("/")
                        if base == "USD" and quote in all_rates:
                            rates[pair] = all_rates[quote]
                        elif quote == "USD" and base in all_rates:
                            rates[pair] = round(1 / all_rates[base], 6)
                    source = name
                    break
            except Exception:
                continue

    payload = {
        "rates":  rates or {},
        "source": source,
        "pairs":  pairs,
    }
    if rates:
        _cache_set(cache_key, payload, _RATES_TTL)

    return {**payload, "cached": False}


# ─────────────────────────────────────────────────────────────────────────────
# OHLC / Candles — Twelve Data primary
# ─────────────────────────────────────────────────────────────────────────────

async def get_ohlc(
    pair: str,
    interval: str = "1min",
    outputsize: int = 100,
) -> dict[str, Any]:
    cache_key = f"ohlc:{pair}:{interval}:{outputsize}"
    cached = _cache_get(cache_key)
    if cached:
        return {**cached, "cached": True}

    symbol = pair.replace("/", "")
    result: dict[str, Any] = {"pair": pair, "interval": interval, "candles": [], "source": "unavailable"}

    # Twelve Data OHLC
    if _TWELVE_DATA_KEY:
        try:
            r = await _client().get(
                "https://api.twelvedata.com/time_series",
                params={
                    "symbol":     symbol,
                    "interval":   interval,
                    "outputsize": outputsize,
                    "apikey":     _TWELVE_DATA_KEY,
                },
            )
            r.raise_for_status()
            data = r.json()
            if "values" in data:
                result["candles"] = [
                    {
                        "datetime": v["datetime"],
                        "open":     float(v["open"]),
                        "high":     float(v["high"]),
                        "low":      float(v["low"]),
                        "close":    float(v["close"]),
                    }
                    for v in data["values"]
                ]
                result["source"] = "twelve_data"
                _cache_set(cache_key, result, _FORECAST_TTL)
                return {**result, "cached": False}
        except Exception as exc:
            logger.warning("Twelve Data OHLC failed: %s", exc)

    # FCS fallback OHLC
    if _FCS_KEY:
        try:
            sym = pair.replace("/", "_")
            r = await _client().get(
                "https://fcsapi.com/api-v3/forex/candle",
                params={
                    "symbol":     sym,
                    "period":     interval,
                    "access_key": _FCS_KEY,
                    "level":      outputsize,
                },
            )
            r.raise_for_status()
            data = r.json()
            if data.get("status") and data.get("response"):
                result["candles"] = [
                    {
                        "datetime": c.get("tm"),
                        "open":     float(c.get("o", 0)),
                        "high":     float(c.get("h", 0)),
                        "low":      float(c.get("l", 0)),
                        "close":    float(c.get("c", 0)),
                    }
                    for c in data["response"]
                ]
                result["source"] = "fcs"
                _cache_set(cache_key, result, _FORECAST_TTL)
                return {**result, "cached": False}
        except Exception as exc:
            logger.warning("FCS OHLC failed: %s", exc)

    return {**result, "cached": False}


# ─────────────────────────────────────────────────────────────────────────────
# NEWS — Finnhub + MarketAux fallback
# ─────────────────────────────────────────────────────────────────────────────

async def get_forex_news(pair: str | None = None, limit: int = 10) -> dict[str, Any]:
    cache_key = f"news:{pair}:{limit}"
    cached = _cache_get(cache_key)
    if cached:
        return {**cached, "cached": True}

    articles: list[dict] = []
    source = "unavailable"

    # Finnhub forex news
    if _FINNHUB_KEY:
        try:
            r = await _client().get(
                "https://finnhub.io/api/v1/news",
                params={"category": "forex", "token": _FINNHUB_KEY},
            )
            r.raise_for_status()
            data = r.json()
            articles = [
                {
                    "headline": item.get("headline", ""),
                    "summary":  item.get("summary", ""),
                    "source":   item.get("source", ""),
                    "url":      item.get("url", ""),
                    "datetime": item.get("datetime"),
                    "sentiment": None,
                }
                for item in (data or [])[:limit]
            ]
            source = "finnhub"
        except Exception as exc:
            logger.warning("Finnhub news failed: %s", exc)

    # MarketAux fallback
    if not articles and _MARKETAUX_ENDPOINT:
        try:
            params: dict[str, Any] = {"limit": limit}
            if pair:
                params["symbols"] = pair.replace("/", "")
            r = await _client().get(_MARKETAUX_ENDPOINT, params=params)
            r.raise_for_status()
            data = r.json()
            raw_articles = data.get("data", data.get("articles", []))
            articles = [
                {
                    "headline": a.get("title", a.get("headline", "")),
                    "summary":  a.get("description", a.get("summary", "")),
                    "source":   a.get("source", ""),
                    "url":      a.get("url", ""),
                    "datetime": a.get("published_at", a.get("datetime")),
                    "sentiment": (a.get("entities") or [{}])[0].get("sentiment_score"),
                }
                for a in raw_articles[:limit]
            ]
            source = "marketaux"
        except Exception as exc:
            logger.warning("MarketAux news failed: %s", exc)

    payload = {"articles": articles, "source": source, "pair": pair}
    if articles:
        _cache_set(cache_key, payload, _NEWS_TTL)

    return {**payload, "cached": False}


# ─────────────────────────────────────────────────────────────────────────────
# SENTIMENT — GDELT
# ─────────────────────────────────────────────────────────────────────────────

async def get_sentiment(pair: str | None = None) -> dict[str, Any]:
    cache_key = f"sentiment:{pair}"
    cached = _cache_get(cache_key)
    if cached:
        return {**cached, "cached": True}

    result: dict[str, Any] = {
        "sentiment": "neutral",
        "score": 0.0,
        "source": "unavailable",
        "pair": pair,
    }

    if _GDELT_ENDPOINT:
        try:
            params: dict[str, Any] = {}
            if pair:
                query = f"forex {pair.replace('/', ' ')}"
                params["query"] = query
            r = await _client().get(_GDELT_ENDPOINT, params=params)
            r.raise_for_status()
            data = r.json()

            # GDELT GKG structure — extract tone
            articles = data.get("articles", data.get("gkg", []))
            if articles:
                tones = [
                    float(a.get("tone", {}).get("tone", 0))
                    if isinstance(a.get("tone"), dict)
                    else float(a.get("tone", 0))
                    for a in articles
                    if a.get("tone") is not None
                ]
                avg_tone = sum(tones) / len(tones) if tones else 0.0
                sentiment = (
                    "bullish" if avg_tone > 1
                    else "bearish" if avg_tone < -1
                    else "neutral"
                )
                result = {
                    "sentiment": sentiment,
                    "score": round(avg_tone, 4),
                    "article_count": len(articles),
                    "source": "gdelt",
                    "pair": pair,
                }
                _cache_set(cache_key, result, _SENTIMENT_TTL)
        except Exception as exc:
            logger.warning("GDELT sentiment failed: %s", exc)

    return {**result, "cached": False}


# ─────────────────────────────────────────────────────────────────────────────
# TECHNICAL INDICATORS — Twelve Data
# ─────────────────────────────────────────────────────────────────────────────

async def get_indicators(
    pair: str,
    indicator: str = "rsi",
    interval: str = "1h",
    period: int = 14,
) -> dict[str, Any]:
    cache_key = f"indicator:{pair}:{indicator}:{interval}:{period}"
    cached = _cache_get(cache_key)
    if cached:
        return {**cached, "cached": True}

    symbol = pair.replace("/", "")
    result: dict[str, Any] = {
        "pair": pair,
        "indicator": indicator,
        "value": None,
        "source": "unavailable",
    }

    if not _TWELVE_DATA_KEY:
        return {**result, "cached": False}

    indicator_endpoints = {
        "rsi":    "rsi",
        "macd":   "macd",
        "ema":    "ema",
        "sma":    "sma",
        "bbands": "bbands",
        "stoch":  "stoch",
        "adx":    "adx",
        "atr":    "atr",
    }
    endpoint_name = indicator_endpoints.get(indicator.lower(), indicator.lower())

    try:
        r = await _client().get(
            f"https://api.twelvedata.com/{endpoint_name}",
            params={
                "symbol":     symbol,
                "interval":   interval,
                "time_period": period,
                "outputsize": 1,
                "apikey":     _TWELVE_DATA_KEY,
            },
        )
        r.raise_for_status()
        data = r.json()

        if "values" in data and data["values"]:
            latest = data["values"][0]
            result = {
                "pair":      pair,
                "indicator": indicator.upper(),
                "interval":  interval,
                "period":    period,
                "value":     {k: float(v) for k, v in latest.items() if k != "datetime"},
                "datetime":  latest.get("datetime"),
                "source":    "twelve_data",
            }
            _cache_set(cache_key, result, _FORECAST_TTL)
    except Exception as exc:
        logger.warning("Twelve Data indicator %s failed: %s", indicator, exc)

    return {**result, "cached": False}


# ─────────────────────────────────────────────────────────────────────────────
# AGGREGATE market snapshot (used by WebSocket stream)
# ─────────────────────────────────────────────────────────────────────────────

async def get_market_snapshot(pairs: list[str] | None = None) -> dict[str, Any]:
    """
    Returns rates + sentiment for all pairs in one call.
    Used by the WebSocket forex stream.
    """
    pairs = pairs or _DEFAULT_PAIRS
    rates_data, sentiment_data = await asyncio.gather(
        get_rates(pairs),
        get_sentiment(),
        return_exceptions=True,
    )

    rates = {}
    if isinstance(rates_data, dict):
        rates = rates_data.get("rates", {})

    sentiment = {}
    if isinstance(sentiment_data, dict):
        sentiment = {
            "score":     sentiment_data.get("score", 0.0),
            "sentiment": sentiment_data.get("sentiment", "neutral"),
            "source":    sentiment_data.get("source", "unavailable"),
        }

    return {
        "rates":     rates,
        "sentiment": sentiment,
        "pairs":     pairs,
        "timestamp": time.time(),
    }


# ─────────────────────────────────────────────────────────────────────────────
# Health check
# ─────────────────────────────────────────────────────────────────────────────

async def health_check() -> dict[str, Any]:
    configured = {
        "twelve_data":     bool(_TWELVE_DATA_KEY),
        "fcs":             bool(_FCS_KEY),
        "forexratesapi":   bool(_FOREXRATE_KEY),
        "exchangeratesapi": bool(_EXCHANGERATES_KEY),
        "itick":           bool(_ITICK_KEY),
        "finnhub":         bool(_FINNHUB_KEY),
        "marketaux":       bool(_MARKETAUX_ENDPOINT),
        "gdelt":           bool(_GDELT_ENDPOINT),
    }
    active_count = sum(1 for v in configured.values() if v)
    try:
        test = await get_rates(["EUR/USD"])
        live_source = test.get("source", "unavailable")
    except Exception:
        live_source = "error"

    return {
        "status":          "ok" if active_count > 0 else "degraded",
        "providers_configured": active_count,
        "providers":       configured,
        "live_source":     live_source,
        "cache_ttls": {
            "rates_seconds":     _RATES_TTL,
            "forecast_seconds":  _FORECAST_TTL,
            "news_seconds":      _NEWS_TTL,
            "sentiment_seconds": _SENTIMENT_TTL,
        },
    }