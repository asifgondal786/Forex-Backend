"""
app/services/market_data_service.py
Live forex prices — Pepperstone FIX (primary) → Yahoo Finance (fallback)
TwelveData removed entirely.
"""
import logging
import time as _time
import json
from datetime import datetime, timezone
import httpx
from pydantic import BaseModel

logger = logging.getLogger(__name__)

SUPPORTED_PAIRS = [
    "EUR_USD", "GBP_USD", "USD_JPY", "AUD_USD", "USD_CAD",
    "USD_CHF", "NZD_USD", "EUR_GBP", "EUR_JPY", "GBP_JPY",
]
DEFAULT_PAIRS     = ["EUR_USD", "GBP_USD", "USD_JPY"]
CACHE_TTL_SECONDS = 10

_mem_cache: dict = {}

_SPREAD_PIPS = {
    "EUR_USD": 1.0, "GBP_USD": 1.5, "USD_JPY": 1.2,
    "AUD_USD": 1.5, "USD_CAD": 2.0, "USD_CHF": 1.5,
    "NZD_USD": 2.0, "EUR_GBP": 1.5, "EUR_JPY": 2.0, "GBP_JPY": 2.5,
}

class PriceQuote(BaseModel):
    instrument: str
    bid: float
    ask: float
    mid: float
    spread: float
    tradeable: bool
    timestamp: str

class MarketPricesResponse(BaseModel):
    prices: list[PriceQuote]
    cached: bool
    fetched_at: str
    source: str


def _estimate_spread(instrument: str, mid: float):
    pip_size    = 0.01 if "JPY" in instrument else 0.0001
    pips        = _SPREAD_PIPS.get(instrument, 2.0)
    half        = (pips / 2) * pip_size
    return round(mid - half, 5), round(mid + half, 5), pips


def _yahoo_symbol(pair: str) -> str:
    return pair.replace("_", "") + "=X"


async def _price_from_pepperstone(valid_pairs: list[str], now_iso: str) -> MarketPricesResponse | None:
    try:
        from app.services.pepperstone_fix_client import pepperstone as _pp
        if not (_pp and _pp.price_ready):
            return None
        quotes = []
        for pair in valid_pairs:
            symbol = pair.replace("_", "")
            px = _pp.get_last_price(symbol)
            if px and px.get("bid") and px.get("ask"):
                bid = float(px["bid"])
                ask = float(px["ask"])
                mid = round((bid + ask) / 2, 5)
                _, _, spread = _estimate_spread(pair, mid)
                quotes.append(PriceQuote(
                    instrument=pair, bid=bid, ask=ask, mid=mid,
                    spread=spread, tradeable=True,
                    timestamp=px.get("timestamp", now_iso),
                ))
        if len(quotes) == len(valid_pairs):
            return MarketPricesResponse(
                prices=quotes, cached=False, fetched_at=now_iso, source="pepperstone"
            )
    except Exception as e:
        logger.debug("Pepperstone price fetch failed: %s", e)
    return None


async def _price_from_yahoo(valid_pairs: list[str], now_iso: str) -> MarketPricesResponse | None:
    try:
        quotes = []
        async with httpx.AsyncClient(timeout=8.0) as client:
            for pair in valid_pairs:
                sym = _yahoo_symbol(pair)
                r = await client.get(
                    f"https://query1.finance.yahoo.com/v8/finance/chart/{sym}",
                    params={"interval": "1m", "range": "1d"},
                    headers={"User-Agent": "Mozilla/5.0"},
                )
                r.raise_for_status()
                result = r.json().get("chart", {}).get("result", [])
                if not result:
                    continue
                meta  = result[0].get("meta", {})
                price = meta.get("regularMarketPrice") or meta.get("previousClose")
                if not price:
                    continue
                mid = round(float(price), 5)
                bid, ask, spread = _estimate_spread(pair, mid)
                quotes.append(PriceQuote(
                    instrument=pair, bid=bid, ask=ask, mid=mid,
                    spread=spread, tradeable=True, timestamp=now_iso,
                ))
        if quotes:
            return MarketPricesResponse(
                prices=quotes, cached=False, fetched_at=now_iso, source="yahoo"
            )
    except Exception as e:
        logger.debug("Yahoo price fetch failed: %s", e)
    return None


async def get_market_prices(
    pairs: list[str],
    redis_client=None,
) -> MarketPricesResponse:
    valid_pairs = [p.upper() for p in pairs if p.upper() in SUPPORTED_PAIRS]
    if not valid_pairs:
        valid_pairs = DEFAULT_PAIRS

    cache_key = "market:prices:" + ",".join(sorted(valid_pairs))
    now_iso   = datetime.now(timezone.utc).isoformat()

    # Memory cache
    entry = _mem_cache.get(cache_key)
    if entry and (_time.monotonic() - entry["ts"]) < CACHE_TTL_SECONDS:
        return MarketPricesResponse(
            prices=[PriceQuote(**q) for q in entry["data"]["prices"]],
            cached=True,
            fetched_at=entry["data"].get("fetched_at", now_iso),
            source=entry["data"].get("source", "cache"),
        )

    # 1. Pepperstone FIX
    result = await _price_from_pepperstone(valid_pairs, now_iso)

    # 2. Yahoo Finance fallback
    if not result:
        result = await _price_from_yahoo(valid_pairs, now_iso)

    # 3. Nothing worked
    if not result:
        return MarketPricesResponse(
            prices=[], cached=False, fetched_at=now_iso, source="error_fallback"
        )

    # Cache result
    _mem_cache[cache_key] = {
        "ts": _time.monotonic(),
        "data": {
            "prices": [q.model_dump() for q in result.prices],
            "fetched_at": now_iso,
            "source": result.source,
        },
    }
    return result


async def get_ohlc_data(pair: str = "EUR/USD", interval: str = "1h", outputsize: int = 100) -> dict:
    """OHLC from Yahoo Finance."""
    sym = pair.replace("/", "").replace("_", "") + "=X"
    range_map = {"1m": "1d", "5m": "5d", "15m": "5d", "1h": "7d", "4h": "1mo", "1d": "6mo"}
    yrange = range_map.get(interval, "7d")
    try:
        async with httpx.AsyncClient(timeout=10.0) as client:
            r = await client.get(
                f"https://query1.finance.yahoo.com/v8/finance/chart/{sym}",
                params={"interval": interval, "range": yrange},
                headers={"User-Agent": "Mozilla/5.0"},
            )
            data = r.json()
        result = data.get("chart", {}).get("result", [])
        if not result:
            return {"values": [], "error": "No data from Yahoo"}
        res       = result[0]
        timestamps = res.get("timestamp", [])
        ohlcv      = res.get("indicators", {}).get("quote", [{}])[0]
        values = []
        for i, ts in enumerate(timestamps):
            o = (ohlcv.get("open")  or [])[i] if i < len(ohlcv.get("open",  [])) else None
            h = (ohlcv.get("high")  or [])[i] if i < len(ohlcv.get("high",  [])) else None
            l = (ohlcv.get("low")   or [])[i] if i < len(ohlcv.get("low",   [])) else None
            c = (ohlcv.get("close") or [])[i] if i < len(ohlcv.get("close", [])) else None
            if all(v is not None for v in [o, h, l, c]):
                values.append({
                    "datetime": datetime.fromtimestamp(ts, tz=timezone.utc).isoformat(),
                    "open": round(o, 5), "high": round(h, 5),
                    "low":  round(l, 5), "close": round(c, 5),
                })
        return {"values": values[-outputsize:], "pair": pair,
                "interval": interval, "source": "yahoo"}
    except Exception as e:
        return {"values": [], "error": str(e)}
