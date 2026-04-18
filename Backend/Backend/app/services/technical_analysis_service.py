"""
app/services/technical_analysis_service.py
Phase 4 - Technical Analysis
Computes RSI and MACD from OHLC data fetched via Twelve Data.
Returns indicator readings + bias for signal fusion.
"""
from __future__ import annotations

import logging
import os
from typing import Dict, List, Optional
import httpx

logger = logging.getLogger(__name__)

TWELVE_DATA_KEY = os.getenv("TWELVE_DATA_API_KEY", "")
TWELVE_DATA_URL = "https://api.twelvedata.com"


async def _fetch_closes(pair: str, interval: str = "1h", count: int = 50) -> List[float]:
    """Fetch closing prices from Twelve Data."""
    if not TWELVE_DATA_KEY:
        return []
    symbol = pair.replace("_", "/")
    try:
        async with httpx.AsyncClient(timeout=10) as client:
            resp = await client.get(
                f"{TWELVE_DATA_URL}/time_series",
                params={
                    "symbol":     symbol,
                    "interval":   interval,
                    "outputsize": count,
                    "apikey":     TWELVE_DATA_KEY,
                },
            )
        data = resp.json()
        values = data.get("values", [])
        closes = [float(v["close"]) for v in values if "close" in v]
        closes.reverse()  # oldest â†’ newest
        return closes
    except Exception as exc:
        logger.warning("Technical data fetch failed for %s: %s", pair, exc)
        return []


def _compute_rsi(closes: List[float], period: int = 14) -> Optional[float]:
    """Compute RSI from closing prices."""
    if len(closes) < period + 1:
        return None
    gains, losses = [], []
    for i in range(1, len(closes)):
        delta = closes[i] - closes[i - 1]
        gains.append(max(delta, 0))
        losses.append(max(-delta, 0))

    avg_gain = sum(gains[-period:]) / period
    avg_loss = sum(losses[-period:]) / period

    if avg_loss == 0:
        return 100.0
    rs = avg_gain / avg_loss
    return round(100 - (100 / (1 + rs)), 2)


def _compute_macd(
    closes: List[float],
    fast: int = 12,
    slow: int = 26,
    signal: int = 9,
) -> Optional[Dict]:
    """Compute MACD line, signal line, and histogram."""
    if len(closes) < slow + signal:
        return None

    def ema(data: List[float], period: int) -> List[float]:
        k = 2 / (period + 1)
        result = [sum(data[:period]) / period]
        for price in data[period:]:
            result.append(price * k + result[-1] * (1 - k))
        return result

    ema_fast = ema(closes, fast)
    ema_slow = ema(closes, slow)
    min_len = min(len(ema_fast), len(ema_slow))
    macd_line = [ema_fast[-(min_len - i)] - ema_slow[-(min_len - i)]
                 for i in range(min_len)]
    if len(macd_line) < signal:
        return None

    signal_line = []
    k = 2 / (signal + 1)
    signal_line = [sum(macd_line[:signal]) / signal]
    for val in macd_line[signal:]:
        signal_line.append(val * k + signal_line[-1] * (1 - k))

    macd_val = macd_line[-1]
    sig_val = signal_line[-1]
    hist = macd_val - sig_val

    return {
        "macd":      round(macd_val, 6),
        "signal":    round(sig_val, 6),
        "histogram": round(hist, 6),
        "bias":      "bullish" if hist > 0 else "bearish",
    }


def _rsi_bias(rsi: float) -> str:
    if rsi >= 70:
        return "overbought"
    if rsi <= 30:
        return "oversold"
    if rsi >= 55:
        return "bullish"
    if rsi <= 45:
        return "bearish"
    return "neutral"


async def get_technical_indicators(pair: str) -> Dict:
    """
    Main entry point. Returns RSI, MACD, and fused technical bias.
    Used by signal_service to enrich Gemini signals.
    """
    closes = await _fetch_closes(pair, interval="1h", count=60)

    if len(closes) < 30:
        return {
            "rsi":           None,
            "macd":          None,
            "technical_bias": "neutral",
            "indicator_tags": ["Insufficient data"],
            "available":     False,
        }

    rsi   = _compute_rsi(closes)
    macd  = _compute_macd(closes)

    tags: List[str] = []
    bias_votes: List[str] = []

    if rsi is not None:
        rb = _rsi_bias(rsi)
        tags.append(f"RSI {rsi:.0f}")
        if rb == "overbought":
            tags.append("Overbought")
            bias_votes.append("bearish")
        elif rb == "oversold":
            tags.append("Oversold")
            bias_votes.append("bullish")
        elif rb in ("bullish", "bearish"):
            bias_votes.append(rb)

    if macd:
        tags.append(f"MACD {macd['bias'].title()}")
        bias_votes.append(macd["bias"])

    # Fuse votes
    bull = bias_votes.count("bullish")
    bear = bias_votes.count("bearish")
    if bull > bear:
        technical_bias = "bullish"
    elif bear > bull:
        technical_bias = "bearish"
    else:
        technical_bias = "neutral"

    return {
        "rsi":            rsi,
        "macd":           macd,
        "technical_bias": technical_bias,
        "indicator_tags": tags,
        "available":      True,
    }