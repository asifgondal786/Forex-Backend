from __future__ import annotations

import asyncio
import logging
import os
import random
import time
from datetime import datetime, timezone
from typing import Any

import httpx
from tenacity import retry, retry_if_exception_type, stop_after_attempt, wait_exponential

logger = logging.getLogger(__name__)

_TWELVE_DATA_KEY = (os.getenv("TWELVE_DATA_API_KEY") or "").strip()
_FCS_KEY = (os.getenv("FCS_API_KEY") or "").strip()
_FOREXRATE_KEY = (os.getenv("FOREXRATEAPI_API_KEY") or "").strip()
_EXCHANGERATES_KEY = (os.getenv("EXCHANGERATESAPI_API_KEY") or "").strip()
_ITICK_KEY = (os.getenv("ITICK_API_KEY") or "").strip()
_FINNHUB_KEY = (os.getenv("FINNHUB_KEY") or "").strip()
_MARKETAUX_VALUE = (
    os.getenv("MARKETAUX_NEWS_ENDPOINT")
    or os.getenv("MARKETAUX_API_KEY")
    or ""
).strip()
_GDELT_ENDPOINT = (os.getenv("GDELT_SENTIMENT_ENDPOINT") or "").strip()

_RATES_TTL = max(1, int((os.getenv("FOREX_RATES_MIN_FETCH_INTERVAL_SECONDS") or "3").strip()))
_FORECAST_TTL = max(1, int((os.getenv("FOREX_FORECAST_CACHE_TTL_SECONDS") or "20").strip()))
_NEWS_TTL = max(1, int((os.getenv("FOREX_NEWS_CACHE_TTL_SECONDS") or "30").strip()))
_SENTIMENT_TTL = max(1, int((os.getenv("FOREX_SENTIMENT_CACHE_TTL_SECONDS") or "15").strip()))

_DEFAULT_PAIRS = [
    "EUR/USD",
    "GBP/USD",
    "USD/JPY",
    "AUD/USD",
    "USD/CAD",
    "USD/CHF",
    "NZD/USD",
    "USD/PKR",
]

_CACHE: dict[str, tuple[Any, float]] = {}
_HTTP_CLIENT: httpx.AsyncClient | None = None


def _normalize_pair(value: str) -> str:
    cleaned = str(value or "").strip().upper().replace("_", "/").replace("-", "/").replace(" ", "")
    if "/" in cleaned:
        base, quote = cleaned.split("/", 1)
        return f"{base}/{quote}"
    if len(cleaned) == 6:
        return f"{cleaned[:3]}/{cleaned[3:]}"
    return cleaned


def _normalize_pairs(pairs: list[str] | None) -> list[str]:
    normalized = [_normalize_pair(pair) for pair in (pairs or _DEFAULT_PAIRS)]
    return [pair for pair in normalized if "/" in pair]


def _cache_get(key: str) -> Any | None:
    entry = _CACHE.get(key)
    if entry is None:
        return None
    value, expires_at = entry
    if time.monotonic() > expires_at:
        del _CACHE[key]
        return None
    return value


def _cache_set(key: str, value: Any, ttl: int) -> None:
    _CACHE[key] = (value, time.monotonic() + ttl)


def _marketaux_request() -> tuple[str, dict[str, Any]] | tuple[None, None]:
    if not _MARKETAUX_VALUE:
        return None, None
    if _MARKETAUX_VALUE.startswith("http://") or _MARKETAUX_VALUE.startswith("https://"):
        return _MARKETAUX_VALUE, {}
    return "https://api.marketaux.com/v1/news/all", {"api_token": _MARKETAUX_VALUE, "language": "en"}


def _safe_float(value: Any) -> float | None:
    try:
        if value is None or value == "":
            return None
        return float(value)
    except Exception:
        return None


def _pair_digits(pair: str) -> int:
    pair_upper = pair.upper()
    if "JPY" in pair_upper or "PKR" in pair_upper:
        return 2
    return 5


def _headline_impact(text: str) -> str:
    lowered = (text or "").lower()
    if any(token in lowered for token in ("cpi", "inflation", "nfp", "rate", "ecb", "fomc", "boj", "boe")):
        return "high"
    if any(token in lowered for token in ("forex", "currency", "usd", "eur", "gbp", "jpy")):
        return "medium"
    return "low"


def _headline_currency(text: str) -> str:
    upper = (text or "").upper()
    for token in ("USD", "EUR", "GBP", "JPY", "AUD", "CAD", "CHF", "NZD", "PKR"):
        if token in upper:
            return token
    return "FX"


def _mock_price(currency_pair: str) -> dict[str, Any]:
    base_prices = {
        "EUR/USD": 1.0850,
        "GBP/USD": 1.2700,
        "USD/JPY": 157.0,
        "AUD/USD": 0.6650,
        "USD/CAD": 1.3600,
        "USD/CHF": 0.7900,
        "NZD/USD": 0.6000,
        "USD/PKR": 279.0,
    }
    pair = _normalize_pair(currency_pair)
    base = base_prices.get(pair, 1.0)
    price = base + random.uniform(-0.005, 0.005)
    spread = random.uniform(0.0001, 0.0005)
    return {
        "pair": pair,
        "price": round(price, _pair_digits(pair)),
        "timestamp": datetime.now(timezone.utc).isoformat(),
        "bid": round(price - spread / 2, _pair_digits(pair)),
        "ask": round(price + spread / 2, _pair_digits(pair)),
        "mock": True,
        "source": "mock",
    }


def _client() -> httpx.AsyncClient:
    global _HTTP_CLIENT
    if _HTTP_CLIENT is None or _HTTP_CLIENT.is_closed:
        _HTTP_CLIENT = httpx.AsyncClient(timeout=10.0)
    return _HTTP_CLIENT


async def close() -> None:
    global _HTTP_CLIENT
    if _HTTP_CLIENT is not None and not _HTTP_CLIENT.is_closed:
        await _HTTP_CLIENT.aclose()
    _HTTP_CLIENT = None


@retry(
    retry=retry_if_exception_type(
        (
            httpx.ConnectError,
            httpx.ReadTimeout,
            httpx.WriteTimeout,
            httpx.RemoteProtocolError,
            httpx.ReadError,
        )
    ),
    wait=wait_exponential(multiplier=1, min=1, max=8),
    stop=stop_after_attempt(3),
    reraise=True,
)
async def _get_json(url: str, *, params: dict[str, Any] | None = None) -> Any:
    response = await _client().get(url, params=params)
    response.raise_for_status()
    return response.json()


async def _rates_twelve_data(pairs: list[str]) -> dict[str, float] | None:
    if not _TWELVE_DATA_KEY:
        return None
    try:
        symbols = ",".join(pair.replace("/", "") for pair in pairs)
        data = await _get_json(
            "https://api.twelvedata.com/price",
            params={"symbol": symbols, "apikey": _TWELVE_DATA_KEY},
        )
        result: dict[str, float] = {}
        if isinstance(data, dict) and "price" in data:
            price = _safe_float(data.get("price"))
            if price is not None:
                result[pairs[0]] = price
        elif isinstance(data, dict):
            for pair in pairs:
                symbol = pair.replace("/", "")
                item = data.get(symbol)
                if isinstance(item, dict):
                    price = _safe_float(item.get("price"))
                    if price is not None:
                        result[pair] = price
        return result or None
    except Exception as exc:
        logger.warning("Twelve Data rates failed: %s", exc)
        return None


async def _rates_fcs(pairs: list[str]) -> dict[str, float] | None:
    if not _FCS_KEY:
        return None
    result: dict[str, float] = {}
    try:
        for pair in pairs:
            data = await _get_json(
                "https://fcsapi.com/api-v3/forex/latest",
                params={"symbol": pair.replace("/", "_"), "access_key": _FCS_KEY},
            )
            if not isinstance(data, dict):
                continue
            response = data.get("response")
            if isinstance(response, list) and response:
                price = _safe_float(response[0].get("c"))
                if price is not None:
                    result[pair] = price
        return result or None
    except Exception as exc:
        logger.warning("FCS rates failed: %s", exc)
        return None


async def _rates_itick(pairs: list[str]) -> dict[str, float] | None:
    if not _ITICK_KEY:
        return None
    result: dict[str, float] = {}
    try:
        for pair in pairs:
            data = await _get_json(
                "https://api.itick.org/forex/quote",
                params={"token": _ITICK_KEY, "symbol": pair.replace("/", "")},
            )
            if not isinstance(data, dict):
                continue
            price = _safe_float((data.get("data") or {}).get("c")) or _safe_float((data.get("data") or {}).get("ask"))
            if price is not None:
                result[pair] = price
        return result or None
    except Exception as exc:
        logger.warning("iTick rates failed: %s", exc)
        return None


async def _rates_forexrateapi(base: str = "USD") -> dict[str, float] | None:
    if not _FOREXRATE_KEY:
        return None
    try:
        data = await _get_json(f"https://v6.exchangerate-api.com/v6/{_FOREXRATE_KEY}/latest/{base}")
        if isinstance(data, dict) and data.get("result") == "success":
            raw_rates = data.get("conversion_rates")
            if isinstance(raw_rates, dict):
                return {
                    str(code).upper(): float(value)
                    for code, value in raw_rates.items()
                    if _safe_float(value) is not None
                }
        return None
    except Exception as exc:
        logger.warning("ForexRateAPI base table failed: %s", exc)
        return None


async def _rates_exchangeratesapi(base: str = "USD") -> dict[str, float] | None:
    if not _EXCHANGERATES_KEY:
        return None
    try:
        data = await _get_json(
            "https://api.exchangeratesapi.io/v1/latest",
            params={"access_key": _EXCHANGERATES_KEY, "base": base},
        )
        if isinstance(data, dict) and data.get("success"):
            raw_rates = data.get("rates")
            if isinstance(raw_rates, dict):
                return {
                    str(code).upper(): float(value)
                    for code, value in raw_rates.items()
                    if _safe_float(value) is not None
                }
        return None
    except Exception as exc:
        logger.warning("ExchangeRatesAPI base table failed: %s", exc)
        return None


def _convert_base_rates_to_pairs(all_rates: dict[str, float], pairs: list[str], *, base: str = "USD") -> dict[str, float]:
    result: dict[str, float] = {}
    base = base.upper()
    for pair in pairs:
        left, right = pair.split("/", 1)
        if left == base and right in all_rates:
            result[pair] = float(all_rates[right])
        elif right == base and left in all_rates and all_rates[left]:
            result[pair] = round(1 / float(all_rates[left]), _pair_digits(pair))
        elif left in all_rates and right in all_rates and all_rates[left]:
            result[pair] = round(float(all_rates[right]) / float(all_rates[left]), _pair_digits(pair))
    return result


async def get_rates(pairs: list[str] | None = None) -> dict[str, Any]:
    normalized_pairs = _normalize_pairs(pairs)
    cache_key = f"rates:{','.join(sorted(normalized_pairs))}"
    cached = _cache_get(cache_key)
    if isinstance(cached, dict):
        return {**cached, "cached": True}

    rates: dict[str, float] | None = None
    source = "unavailable"

    for name, provider in (
        ("twelve_data", _rates_twelve_data),
        ("fcs", _rates_fcs),
        ("itick", _rates_itick),
    ):
        rates = await provider(normalized_pairs)
        if rates:
            source = name
            break

    if not rates:
        for name, provider in (
            ("forexrateapi", _rates_forexrateapi),
            ("exchangeratesapi", _rates_exchangeratesapi),
        ):
            all_rates = await provider("USD")
            if all_rates:
                converted = _convert_base_rates_to_pairs(all_rates, normalized_pairs, base="USD")
                if converted:
                    rates = converted
                    source = name
                    break

    payload = {
        "rates": rates or {},
        "pairs": normalized_pairs,
        "source": source,
        "timestamp": datetime.now(timezone.utc).isoformat(),
    }
    if rates:
        _cache_set(cache_key, payload, _RATES_TTL)
    return {**payload, "cached": False}


async def get_ohlc(pair: str, interval: str = "1h", outputsize: int = 100) -> dict[str, Any]:
    normalized_pair = _normalize_pair(pair)
    cache_key = f"ohlc:{normalized_pair}:{interval}:{outputsize}"
    cached = _cache_get(cache_key)
    if isinstance(cached, dict):
        return {**cached, "cached": True}

    result: dict[str, Any] = {
        "pair": normalized_pair,
        "interval": interval,
        "candles": [],
        "source": "unavailable",
    }
    symbol = normalized_pair.replace("/", "")

    if _TWELVE_DATA_KEY:
        try:
            data = await _get_json(
                "https://api.twelvedata.com/time_series",
                params={
                    "symbol": symbol,
                    "interval": interval,
                    "outputsize": outputsize,
                    "apikey": _TWELVE_DATA_KEY,
                },
            )
            values = data.get("values") if isinstance(data, dict) else None
            if isinstance(values, list) and values:
                result["candles"] = [
                    {
                        "datetime": item.get("datetime"),
                        "open": _safe_float(item.get("open")) or 0.0,
                        "high": _safe_float(item.get("high")) or 0.0,
                        "low": _safe_float(item.get("low")) or 0.0,
                        "close": _safe_float(item.get("close")) or 0.0,
                    }
                    for item in values
                ]
                result["source"] = "twelve_data"
                _cache_set(cache_key, result, _FORECAST_TTL)
                return {**result, "cached": False}
        except Exception as exc:
            logger.warning("Twelve Data OHLC failed: %s", exc)

    if _FCS_KEY:
        try:
            data = await _get_json(
                "https://fcsapi.com/api-v3/forex/candle",
                params={
                    "symbol": normalized_pair.replace("/", "_"),
                    "period": interval,
                    "access_key": _FCS_KEY,
                    "level": outputsize,
                },
            )
            response = data.get("response") if isinstance(data, dict) else None
            if isinstance(response, list) and response:
                result["candles"] = [
                    {
                        "datetime": item.get("tm"),
                        "open": _safe_float(item.get("o")) or 0.0,
                        "high": _safe_float(item.get("h")) or 0.0,
                        "low": _safe_float(item.get("l")) or 0.0,
                        "close": _safe_float(item.get("c")) or 0.0,
                    }
                    for item in response
                ]
                result["source"] = "fcs"
                _cache_set(cache_key, result, _FORECAST_TTL)
                return {**result, "cached": False}
        except Exception as exc:
            logger.warning("FCS OHLC failed: %s", exc)

    return {**result, "cached": False}


async def get_forex_news(pair: str | None = None, limit: int = 10) -> dict[str, Any]:
    normalized_pair = _normalize_pair(pair) if pair else None
    cache_key = f"news:{normalized_pair}:{limit}"
    cached = _cache_get(cache_key)
    if isinstance(cached, dict):
        return {**cached, "cached": True}

    articles: list[dict[str, Any]] = []
    source = "unavailable"

    if _FINNHUB_KEY:
        try:
            data = await _get_json(
                "https://finnhub.io/api/v1/news",
                params={"category": "forex", "token": _FINNHUB_KEY},
            )
            if isinstance(data, list):
                articles = [
                    {
                        "headline": item.get("headline", ""),
                        "summary": item.get("summary", ""),
                        "source": item.get("source", ""),
                        "url": item.get("url", ""),
                        "datetime": item.get("datetime"),
                        "sentiment": None,
                    }
                    for item in data[:limit]
                ]
                source = "finnhub"
        except Exception as exc:
            logger.warning("Finnhub news failed: %s", exc)

    endpoint, static_params = _marketaux_request()
    if not articles and endpoint:
        try:
            params: dict[str, Any] = {"limit": limit, **(static_params or {})}
            if normalized_pair:
                params["symbols"] = normalized_pair.replace("/", "")
            data = await _get_json(endpoint, params=params)
            raw_articles: list[dict[str, Any]] = []
            if isinstance(data, dict):
                maybe_data = data.get("data")
                if isinstance(maybe_data, list):
                    raw_articles = maybe_data
                elif isinstance(data.get("articles"), list):
                    raw_articles = data.get("articles")
            articles = [
                {
                    "headline": item.get("title", item.get("headline", "")),
                    "summary": item.get("description", item.get("summary", "")),
                    "source": item.get("source", ""),
                    "url": item.get("url", ""),
                    "datetime": item.get("published_at", item.get("datetime")),
                    "sentiment": ((item.get("entities") or [{}])[0]).get("sentiment_score"),
                }
                for item in raw_articles[:limit]
            ]
            if articles:
                source = "marketaux"
        except Exception as exc:
            logger.warning("MarketAux news failed: %s", exc)

    payload = {
        "articles": articles,
        "pair": normalized_pair,
        "source": source,
        "timestamp": datetime.now(timezone.utc).isoformat(),
    }
    if articles:
        _cache_set(cache_key, payload, _NEWS_TTL)
    return {**payload, "cached": False}


async def get_sentiment(pair: str | None = None) -> dict[str, Any]:
    normalized_pair = _normalize_pair(pair) if pair else None
    cache_key = f"sentiment:{normalized_pair}"
    cached = _cache_get(cache_key)
    if isinstance(cached, dict):
        return {**cached, "cached": True}

    result: dict[str, Any] = {
        "sentiment": "neutral",
        "score": 0.0,
        "source": "unavailable",
        "pair": normalized_pair,
        "article_count": 0,
    }

    if _GDELT_ENDPOINT:
        try:
            params: dict[str, Any] = {}
            if normalized_pair:
                params["query"] = f"forex {normalized_pair.replace('/', ' ')}"
            data = await _get_json(_GDELT_ENDPOINT, params=params or None)
            articles: list[Any] = []
            if isinstance(data, dict):
                for key in ("articles", "gkg", "data", "items"):
                    value = data.get(key)
                    if isinstance(value, list):
                        articles = value
                        break
            if articles:
                tones = []
                for article in articles:
                    if not isinstance(article, dict):
                        continue
                    tone = article.get("tone")
                    if isinstance(tone, dict):
                        tone = tone.get("tone")
                    numeric = _safe_float(tone)
                    if numeric is not None:
                        tones.append(numeric)
                avg_tone = sum(tones) / len(tones) if tones else 0.0
                result = {
                    "sentiment": "bullish" if avg_tone > 1 else "bearish" if avg_tone < -1 else "neutral",
                    "score": round(avg_tone, 4),
                    "source": "gdelt",
                    "pair": normalized_pair,
                    "article_count": len(articles),
                }
                _cache_set(cache_key, result, _SENTIMENT_TTL)
                return {**result, "cached": False}
        except Exception as exc:
            logger.warning("GDELT sentiment failed: %s", exc)

    news = await get_forex_news(normalized_pair, limit=5)
    headlines = [item.get("headline", "") for item in news.get("articles", [])]
    score = 0.0
    for headline in headlines:
        lowered = headline.lower()
        if any(token in lowered for token in ("surge", "rise", "gain", "bullish", "rebound")):
            score += 1.0
        if any(token in lowered for token in ("drop", "fall", "bearish", "selloff", "recession")):
            score -= 1.0
    if headlines:
        score = score / len(headlines)
        result = {
            "sentiment": "bullish" if score > 0.15 else "bearish" if score < -0.15 else "neutral",
            "score": round(score, 4),
            "source": f"{news.get('source', 'news')}_derived",
            "pair": normalized_pair,
            "article_count": len(headlines),
        }
        _cache_set(cache_key, result, _SENTIMENT_TTL)
    return {**result, "cached": False}


async def get_indicators(pair: str, indicator: str = "rsi", interval: str = "1h", period: int = 14) -> dict[str, Any]:
    normalized_pair = _normalize_pair(pair)
    cache_key = f"indicator:{normalized_pair}:{indicator}:{interval}:{period}"
    cached = _cache_get(cache_key)
    if isinstance(cached, dict):
        return {**cached, "cached": True}

    result: dict[str, Any] = {
        "pair": normalized_pair,
        "indicator": indicator.upper(),
        "interval": interval,
        "period": period,
        "value": None,
        "source": "unavailable",
    }
    if not _TWELVE_DATA_KEY:
        return {**result, "cached": False}

    endpoint_name = indicator.strip().lower()
    try:
        data = await _get_json(
            f"https://api.twelvedata.com/{endpoint_name}",
            params={
                "symbol": normalized_pair.replace("/", ""),
                "interval": interval,
                "time_period": period,
                "outputsize": 1,
                "apikey": _TWELVE_DATA_KEY,
            },
        )
        values = data.get("values") if isinstance(data, dict) else None
        if isinstance(values, list) and values:
            latest = values[0]
            parsed_value = {
                key: float(value)
                for key, value in latest.items()
                if key != "datetime" and _safe_float(value) is not None
            }
            result = {
                "pair": normalized_pair,
                "indicator": indicator.upper(),
                "interval": interval,
                "period": period,
                "value": parsed_value,
                "datetime": latest.get("datetime"),
                "source": "twelve_data",
            }
            _cache_set(cache_key, result, _FORECAST_TTL)
    except Exception as exc:
        logger.warning("Indicator %s failed for %s: %s", indicator, normalized_pair, exc)

    return {**result, "cached": False}


async def get_market_snapshot(pairs: list[str] | None = None) -> dict[str, Any]:
    normalized_pairs = _normalize_pairs(pairs)
    rates_data, sentiment_data = await asyncio.gather(
        get_rates(normalized_pairs),
        get_sentiment(normalized_pairs[0] if normalized_pairs else None),
        return_exceptions=True,
    )
    rates = rates_data.get("rates", {}) if isinstance(rates_data, dict) else {}
    sentiment = sentiment_data if isinstance(sentiment_data, dict) else {
        "sentiment": "neutral",
        "score": 0.0,
        "source": "unavailable",
    }
    return {
        "pairs": normalized_pairs,
        "rates": rates,
        "sentiment": {
            "sentiment": sentiment.get("sentiment", "neutral"),
            "score": sentiment.get("score", 0.0),
            "source": sentiment.get("source", "unavailable"),
        },
        "timestamp": datetime.now(timezone.utc).isoformat(),
    }


async def health_check() -> dict[str, Any]:
    configured = {
        "twelve_data": bool(_TWELVE_DATA_KEY),
        "fcs": bool(_FCS_KEY),
        "forexrateapi": bool(_FOREXRATE_KEY),
        "exchangeratesapi": bool(_EXCHANGERATES_KEY),
        "itick": bool(_ITICK_KEY),
        "finnhub": bool(_FINNHUB_KEY),
        "marketaux": bool(_MARKETAUX_VALUE),
        "gdelt": bool(_GDELT_ENDPOINT),
    }
    try:
        sample = await get_rates(["EUR/USD"])
        live_source = sample.get("source", "unavailable")
    except Exception:
        live_source = "error"
    return {
        "status": "ok" if any(configured.values()) else "degraded",
        "providers_configured": sum(1 for value in configured.values() if value),
        "providers": configured,
        "live_source": live_source,
        "cache_ttls": {
            "rates_seconds": _RATES_TTL,
            "forecast_seconds": _FORECAST_TTL,
            "news_seconds": _NEWS_TTL,
            "sentiment_seconds": _SENTIMENT_TTL,
        },
    }


class ForexDataService:
    """Compatibility wrapper used by older service callers."""

    async def get_realtime_price(self, currency_pair: str) -> dict[str, Any]:
        normalized_pair = _normalize_pair(currency_pair)
        data = await get_rates([normalized_pair])
        price = _safe_float((data.get("rates") or {}).get(normalized_pair))
        if price is None:
            return _mock_price(normalized_pair)
        spread = max(price * 0.0002, 0.00005)
        return {
            "pair": normalized_pair,
            "price": round(price, _pair_digits(normalized_pair)),
            "timestamp": data.get("timestamp", datetime.now(timezone.utc).isoformat()),
            "bid": round(price - spread / 2, _pair_digits(normalized_pair)),
            "ask": round(price + spread / 2, _pair_digits(normalized_pair)),
            "source": data.get("source", "unavailable"),
            "cached": data.get("cached", False),
        }

    async def get_historical_data(
        self,
        currency_pair: str,
        timeframe: str = "1h",
        output_size: int = 100,
    ) -> dict[str, Any]:
        return await get_ohlc(currency_pair, interval=timeframe, outputsize=output_size)

    def _generate_mock_price(self, currency_pair: str) -> dict[str, Any]:
        return _mock_price(currency_pair)

    async def close(self) -> None:
        await close()
