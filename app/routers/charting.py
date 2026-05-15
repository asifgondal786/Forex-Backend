"""
Charting Router - Tajir Forex Companion
Serves OHLCV candle data and indicator data to the Flutter TradingView chart.

Endpoints:
  GET /api/v1/chart/candles/{pair}     - OHLCV candlestick data (Yahoo Finance)
  GET /api/v1/chart/indicators/{pair}  - RSI, SMA, EMA, Bollinger Bands
  GET /api/v1/chart/pairs              - list of supported pairs

Data source: Yahoo Finance via market_data_service.get_ohlc_data()
Pepperstone FIX used for live price only (not OHLC history).
"""

import logging
from typing import Optional

from fastapi import APIRouter, Depends, HTTPException, Query
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials

from app.utils.firestore_client import verify_firebase_token

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/api/v1/chart", tags=["Charting"])

SUPPORTED_PAIRS = [
    "EUR_USD", "GBP_USD", "USD_JPY", "AUD_USD", "USD_CAD",
    "USD_CHF", "NZD_USD", "EUR_GBP", "EUR_JPY", "GBP_JPY", "XAU_USD",
]

TIMEFRAME_MAP = {
    "1m": "1m", "5m": "5m", "15m": "15m", "30m": "30m",
    "1h": "1h", "4h": "4h", "1d": "1d",
}

_bearer = HTTPBearer(auto_error=False)


async def get_current_user(
    credentials: Optional[HTTPAuthorizationCredentials] = Depends(_bearer),
) -> dict:
    if not credentials or not credentials.credentials:
        raise HTTPException(status_code=401, detail="Authentication required.")
    try:
        claims = verify_firebase_token(credentials.credentials)
        return claims
    except Exception as exc:
        logger.warning("Chart auth failed: %s", exc)
        raise HTTPException(status_code=401, detail="Invalid or expired token.")


async def _get_candles(pair: str, granularity: str, count: int) -> list[dict]:
    """Fetch OHLCV candles from Yahoo Finance via market_data_service."""
    try:
        from app.services.market_data_service import get_ohlc_data
        pair_fmt = pair.replace("-", "/").replace("_", "/")
        interval = TIMEFRAME_MAP.get(granularity.lower(), "1h")
        result = await get_ohlc_data(pair_fmt, interval=interval, outputsize=count)
        return result.get("values", [])
    except Exception as e:
        logger.error("_get_candles failed for %s: %s", pair, e)
        return []


@router.get("/pairs")
async def list_pairs():
    """Return list of supported trading pairs."""
    return {"pairs": SUPPORTED_PAIRS, "source": "yahoo"}


@router.get("/candles/{pair}")
async def get_candles(
    pair: str,
    granularity: str = Query(default="1h", description="Timeframe: 1m 5m 15m 30m 1h 4h 1d"),
    count: int = Query(default=100, ge=10, le=500),
    user: dict = Depends(get_current_user),
):
    """
    OHLCV candlestick data for TradingView charts.
    Source: Yahoo Finance
    """
    pair_clean = pair.upper().replace("-", "_").replace("/", "_")
    if len(pair_clean) == 6 and "_" not in pair_clean:
        pair_clean = pair_clean[:3] + "_" + pair_clean[3:]
    if pair_clean not in SUPPORTED_PAIRS:
        raise HTTPException(status_code=400, detail=f"Unsupported pair: {pair}. Use format EUR_USD")

    granularity_clean = granularity.lower()
    if granularity_clean not in TIMEFRAME_MAP:
        raise HTTPException(status_code=400, detail=f"Unsupported timeframe: {granularity}. Use: {list(TIMEFRAME_MAP.keys())}")

    candles = await _get_candles(pair_clean, granularity_clean, count)

    return {
        "pair":        pair_clean,
        "granularity": granularity_clean,
        "count":       len(candles),
        "source":      "yahoo",
        "candles":     candles,
    }


@router.get("/indicators/{pair}")
async def get_indicators(
    pair: str,
    granularity: str = Query(default="1h"),
    user: dict = Depends(get_current_user),
):
    """
    Technical indicators: RSI, SMA20, SMA50, EMA20, Bollinger Bands.
    Computed from Yahoo Finance OHLCV data.
    """
    pair_clean = pair.upper().replace("-", "_")
    candles = await _get_candles(pair_clean, granularity, 100)

    if len(candles) < 20:
        raise HTTPException(status_code=503, detail="Insufficient data for indicators.")

    closes = [c["close"] for c in candles]

    def sma(data, period):
        if len(data) < period:
            return None
        return round(sum(data[-period:]) / period, 5)

    def ema(data, period):
        if len(data) < period:
            return None
        k = 2 / (period + 1)
        val = sum(data[:period]) / period
        for price in data[period:]:
            val = price * k + val * (1 - k)
        return round(val, 5)

    def rsi(data, period=14):
        if len(data) < period + 1:
            return None
        gains, losses = [], []
        for i in range(1, len(data)):
            diff = data[i] - data[i - 1]
            gains.append(max(diff, 0))
            losses.append(max(-diff, 0))
        avg_gain = sum(gains[-period:]) / period
        avg_loss = sum(losses[-period:]) / period
        if avg_loss == 0:
            return 100.0
        rs = avg_gain / avg_loss
        return round(100 - (100 / (1 + rs)), 2)

    sma20 = sma(closes, 20)
    bb_upper = round(sma20 + 2 * (sum((c - sma20) ** 2 for c in closes[-20:]) / 20) ** 0.5, 5) if sma20 else None
    bb_lower = round(sma20 - 2 * (sum((c - sma20) ** 2 for c in closes[-20:]) / 20) ** 0.5, 5) if sma20 else None

    return {
        "pair":       pair_clean,
        "granularity": granularity,
        "source":     "yahoo_computed",
        "indicators": {
            "rsi":       rsi(closes),
            "sma20":     sma20,
            "sma50":     sma(closes, 50),
            "ema20":     ema(closes, 20),
            "bb_upper":  bb_upper,
            "bb_lower":  bb_lower,
            "last_close": closes[-1] if closes else None,
        }
    }
