"""
Phase 16 — Charting Router
Serves OHLCV candle data and indicator data to the Flutter TradingView chart.

Endpoints:
  GET /api/v1/chart/candles/{pair}     — OHLCV candlestick data
  GET /api/v1/chart/indicators/{pair}  — SMA, EMA, RSI, Bollinger Bands
  GET /api/v1/chart/pairs              — list of supported pairs

Data source priority:
  1. OANDA (Phase 15, when OANDA_API_KEY is set in Railway)
  2. Mock generator (Phase 16 fallback — realistic random walk)
"""

import os
import logging
from typing import Optional
from fastapi import APIRouter, Depends, Query
from datetime import datetime

from app.core.firebase_auth import get_current_user
from app.services.mock_candle_generator import generate_mock_candles, PAIR_CONFIG, TIMEFRAME_MINUTES

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/api/v1/chart", tags=["Charting"])


def _get_candles(pair: str, granularity: str, count: int) -> list[dict]:
    """
    Smart data source selector:
    - Uses OANDA if OANDA_API_KEY is set (Phase 15)
    - Falls back to mock generator (Phase 16)
    """
    if os.getenv("OANDA_API_KEY"):
        # Phase 15 path — import only when available
        try:
            import asyncio
            from app.services.oanda_service import fetch_candles
            loop = asyncio.new_event_loop()
            candles = loop.run_until_complete(fetch_candles(pair, granularity, count))
            loop.close()
            if candles:
                return candles
        except Exception as e:
            logger.warning(f"OANDA candles failed, using mock: {e}")

    # Phase 16 path — mock generator
    return generate_mock_candles(pair, granularity, count)


# ─────────────────────────────────────────────
# Candle Endpoint
# ─────────────────────────────────────────────

@router.get("/candles/{pair}")
async def get_candles(
    pair: str,
    granularity: str = Query("M15", description="M1 M5 M15 M30 H1 H4 D W"),
    count: int = Query(150, ge=20, le=500),
    current_user: dict = Depends(get_current_user),
):
    """
    Get OHLCV candlestick data for TradingView chart.
    Uses OANDA when available, mock data otherwise.
    """
    valid_tfs = list(TIMEFRAME_MINUTES.keys())
    if granularity.upper() not in valid_tfs:
        granularity = "M15"

    candles = _get_candles(pair.upper(), granularity.upper(), count)
    source = "oanda" if os.getenv("OANDA_API_KEY") else "mock"

    return {
        "pair":        pair.upper(),
        "granularity": granularity.upper(),
        "count":       len(candles),
        "source":      source,
        "candles":     candles,
    }


# ─────────────────────────────────────────────
# Indicators Endpoint
# ─────────────────────────────────────────────

def _sma(closes: list[float], period: int) -> list[Optional[float]]:
    result = [None] * len(closes)
    for i in range(period - 1, len(closes)):
        result[i] = round(sum(closes[i - period + 1: i + 1]) / period, 5)
    return result


def _ema(closes: list[float], period: int) -> list[Optional[float]]:
    result = [None] * len(closes)
    if len(closes) < period:
        return result
    k = 2 / (period + 1)
    # Seed with SMA
    result[period - 1] = sum(closes[:period]) / period
    for i in range(period, len(closes)):
        result[i] = round(closes[i] * k + result[i - 1] * (1 - k), 5)
    return result


def _rsi(closes: list[float], period: int = 14) -> list[Optional[float]]:
    result = [None] * len(closes)
    if len(closes) < period + 1:
        return result
    gains, losses = [], []
    for i in range(1, len(closes)):
        delta = closes[i] - closes[i - 1]
        gains.append(max(delta, 0))
        losses.append(max(-delta, 0))
    avg_gain = sum(gains[:period]) / period
    avg_loss = sum(losses[:period]) / period
    for i in range(period, len(closes) - 1):
        avg_gain = (avg_gain * (period - 1) + gains[i]) / period
        avg_loss = (avg_loss * (period - 1) + losses[i]) / period
        rs = avg_gain / avg_loss if avg_loss != 0 else 100
        result[i + 1] = round(100 - (100 / (1 + rs)), 2)
    return result


def _bollinger(closes: list[float], period: int = 20, std_dev: float = 2.0):
    upper, middle, lower = [None]*len(closes), [None]*len(closes), [None]*len(closes)
    for i in range(period - 1, len(closes)):
        window = closes[i - period + 1: i + 1]
        avg = sum(window) / period
        variance = sum((x - avg) ** 2 for x in window) / period
        std = variance ** 0.5
        middle[i] = round(avg, 5)
        upper[i]  = round(avg + std_dev * std, 5)
        lower[i]  = round(avg - std_dev * std, 5)
    return upper, middle, lower


@router.get("/indicators/{pair}")
async def get_indicators(
    pair: str,
    granularity: str = Query("M15"),
    count: int = Query(150, ge=50, le=500),
    sma_period: int = Query(20),
    ema_period: int = Query(21),
    rsi_period: int = Query(14),
    current_user: dict = Depends(get_current_user),
):
    """
    Calculate and return technical indicators for the chart.
    Computed server-side from candle data.

    Returns: SMA, EMA, RSI, Bollinger Bands — all time-aligned with candles.
    """
    candles = _get_candles(pair.upper(), granularity.upper(), count)
    if not candles:
        return {"pair": pair, "indicators": {}}

    times  = [c["time"]  for c in candles]
    closes = [c["close"] for c in candles]

    sma_values            = _sma(closes, sma_period)
    ema_values            = _ema(closes, ema_period)
    rsi_values            = _rsi(closes, rsi_period)
    bb_upper, bb_mid, bb_lower = _bollinger(closes, 20, 2.0)

    def _zip(values):
        return [{"time": t, "value": v} for t, v in zip(times, values) if v is not None]

    return {
        "pair":        pair.upper(),
        "granularity": granularity.upper(),
        "indicators": {
            "sma":              {"period": sma_period, "data": _zip(sma_values)},
            "ema":              {"period": ema_period, "data": _zip(ema_values)},
            "rsi":              {"period": rsi_period, "data": _zip(rsi_values)},
            "bollinger_upper":  {"data": _zip(bb_upper)},
            "bollinger_middle": {"data": _zip(bb_mid)},
            "bollinger_lower":  {"data": _zip(bb_lower)},
        },
    }


# ─────────────────────────────────────────────
# Supported Pairs
# ─────────────────────────────────────────────

@router.get("/pairs")
async def get_supported_pairs(current_user: dict = Depends(get_current_user)):
    """List all supported currency pairs for the chart selector."""
    pairs = [
        {"pair": k, "display": f"{k[:3]}/{k[3:]}", "category": "major"}
        for k in PAIR_CONFIG.keys()
    ]
    return {"pairs": pairs, "count": len(pairs)}