"""
Backend/app/services/market_data_service.py

Twelve Data forex market data service.
Drop-in replacement for the OANDA version â€” identical response models,
identical Redis caching strategy (TTL=2s), identical fallback behaviour.

Free tier: 800 requests/day, 8 requests/minute.
Paid tiers available if you need higher throughput later.

Docs: https://twelvedata.com/docs
"""

import os
import json
import logging
from datetime import datetime, timezone

import httpx
from pydantic import BaseModel

logger = logging.getLogger(__name__)

# â”€â”€ Config â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

TWELVE_DATA_API_KEY = os.getenv("TWELVE_DATA_API_KEY", "")
TWELVE_DATA_BASE    = "https://api.twelvedata.com"

SUPPORTED_PAIRS = [
    "EUR_USD", "GBP_USD", "USD_JPY", "AUD_USD", "USD_CAD",
    "USD_CHF", "NZD_USD", "EUR_GBP", "EUR_JPY", "GBP_JPY",
]
DEFAULT_PAIRS     = ["EUR_USD", "GBP_USD", "USD_JPY"]
CACHE_TTL_SECONDS = 2


# â”€â”€ Pydantic models (identical to OANDA version â€” Flutter side unchanged) â”€â”€â”€â”€â”€â”€

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


# â”€â”€ Helpers â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

def _to_twelve(instrument: str) -> str:
    """EUR_USD â†’ EUR/USD"""
    return instrument.replace("_", "/")

def _to_internal(symbol: str) -> str:
    """EUR/USD â†’ EUR_USD"""
    return symbol.replace("/", "_")

def _estimate_spread(instrument: str, mid: float) -> tuple[float, float, float]:
    """
    Twelve Data free tier returns mid price only (no bid/ask).
    We apply typical market spreads so the rest of the app works identically.
    """
    typical_pips = {
        "EUR_USD": 1.0, "GBP_USD": 1.5, "USD_JPY": 1.2,
        "AUD_USD": 1.5, "USD_CAD": 2.0, "USD_CHF": 1.5,
        "NZD_USD": 2.0, "EUR_GBP": 1.5, "EUR_JPY": 2.0, "GBP_JPY": 2.5,
    }
    pip_size        = 0.01 if "JPY" in instrument else 0.0001
    half_spread     = (typical_pips.get(instrument, 2.0) / 2) * pip_size
    bid             = round(mid - half_spread, 5)
    ask             = round(mid + half_spread, 5)
    spread          = typical_pips.get(instrument, 2.0)
    return bid, ask, spread


def _parse_twelve_response(raw: dict, requested_pairs: list[str]) -> list[PriceQuote]:
    """
    Parse Twelve Data /price batch response.

    Single pair:  {"price": "1.08423", "timestamp": 1710000000}
    Batch:        {"EUR/USD": {"price": "1.08423", ...}, "GBP/USD": {...}}
    """
    quotes: list[PriceQuote] = []
    now_iso = datetime.now(timezone.utc).isoformat()

    # Wrap single-pair response into batch format
    if "price" in raw and len(requested_pairs) == 1:
        raw = {_to_twelve(requested_pairs[0]): raw}

    for twelve_symbol, data in raw.items():
        if not isinstance(data, dict) or "price" not in data:
            logger.warning("Unexpected Twelve Data entry for %s: %s", twelve_symbol, data)
            continue

        instrument       = _to_internal(twelve_symbol)
        mid              = round(float(data["price"]), 5)
        bid, ask, spread = _estimate_spread(instrument, mid)

        ts = data.get("timestamp")
        timestamp = (
            datetime.fromtimestamp(int(ts), tz=timezone.utc).isoformat()
            if ts else now_iso
        )

        quotes.append(PriceQuote(
            instrument=instrument,
            bid=bid,
            ask=ask,
            mid=mid,
            spread=spread,
            tradeable=True,
            timestamp=timestamp,
        ))

    return quotes


# â”€â”€ Main service (identical signature to OANDA version) â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

async def get_market_prices(
    pairs: list[str],
    redis_client=None,
) -> MarketPricesResponse:
    """
    Fetch live forex prices from Twelve Data.

    Flow:
      1. Validate pairs
      2. Check Redis cache (TTL=2s)
      3. Cache miss â†’ call Twelve Data /price (batch)
      4. Store result in Redis
      5. Return MarketPricesResponse
    """
    valid_pairs = [p.upper() for p in pairs if p.upper() in SUPPORTED_PAIRS]
    if not valid_pairs:
        valid_pairs = DEFAULT_PAIRS

    cache_key = "market:prices:" + ",".join(sorted(valid_pairs))
    now_iso   = datetime.now(timezone.utc).isoformat()

    # 1. Redis cache check
    if redis_client:
        try:
            cached = await redis_client.get(cache_key)
            if cached:
                data = json.loads(cached)
                return MarketPricesResponse(
                    prices=[PriceQuote(**q) for q in data["prices"]],
                    cached=True,
                    fetched_at=data.get("fetched_at", now_iso),
                    source="cache",
                )
        except Exception as e:
            logger.warning("Redis cache read failed: %s", e)

    # 2. API key guard
    if not TWELVE_DATA_API_KEY:
        logger.error("TWELVE_DATA_API_KEY not set")
        return MarketPricesResponse(
            prices=[], cached=False, fetched_at=now_iso, source="error_fallback"
        )

    # 3. Call Twelve Data
    symbols = ",".join(_to_twelve(p) for p in valid_pairs)
    try:
        async with httpx.AsyncClient(timeout=8.0) as client:
            resp = await client.get(
                f"{TWELVE_DATA_BASE}/price",
                params={"symbol": symbols, "apikey": TWELVE_DATA_API_KEY, "dp": 5},
            )
        resp.raise_for_status()
        raw = resp.json()

        # Soft error e.g. invalid key
        if isinstance(raw, dict) and raw.get("status") == "error":
            logger.error("Twelve Data error: %s", raw.get("message"))
            return MarketPricesResponse(
                prices=[], cached=False, fetched_at=now_iso, source="error_fallback"
            )

        quotes = _parse_twelve_response(raw, valid_pairs)

    except httpx.HTTPStatusError as e:
        logger.error("Twelve Data HTTP %s: %s", e.response.status_code, e.response.text)
        return MarketPricesResponse(
            prices=[], cached=False, fetched_at=now_iso, source="error_fallback"
        )
    except Exception as e:
        logger.error("Twelve Data fetch failed: %s", e)
        return MarketPricesResponse(
            prices=[], cached=False, fetched_at=now_iso, source="error_fallback"
        )

    result = MarketPricesResponse(
        prices=quotes, cached=False, fetched_at=now_iso, source="twelve_data"
    )

    # 4. Store in Redis
    if redis_client and quotes:
        try:
            payload = json.dumps({
                "prices": [q.model_dump() for q in quotes],
                "fetched_at": now_iso,
            })
            await redis_client.set(cache_key, payload, ex=CACHE_TTL_SECONDS)
        except Exception as e:
            logger.warning("Redis cache write failed: %s", e)

    return result
async def get_ohlc_data(pair: str = "EUR/USD", interval: str = "1h", outputsize: int = 100) -> dict:
    """Fetch OHLC candlestick data from Twelve Data."""
    import httpx, os
    from datetime import timezone
    api_key = os.getenv("TWELVE_DATA_API_KEY", "")
    symbol = _to_twelve(pair)
    url = (
        f"https://api.twelvedata.com/time_series"
        f"?symbol={symbol}&interval={interval}&outputsize={outputsize}"
        f"&apikey={api_key}&format=JSON"
    )
    try:
        async with httpx.AsyncClient(timeout=10) as client:
            resp = await client.get(url)
            data = resp.json()
        if data.get("status") == "error":
            return {"values": [], "error": data.get("message", "Twelve Data error")}
        values = data.get("values", [])
        # Twelve Data returns newest first — reverse for chart chronological order
        values = list(reversed(values))
        return {"values": values, "pair": pair, "interval": interval}
    except Exception as e:
        return {"values": [], "error": str(e)}
