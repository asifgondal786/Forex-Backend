"""
Phase 16 â€” Mock Candle Generator
Generates realistic-looking OHLCV candlestick data for all major pairs.
Used when OANDA is not configured (Phase 15 queued).
Automatically replaced by real OANDA data once Phase 15 is activated.

Uses a seeded random walk with realistic pip sizes, volatility,
and spread per pair â€” so data looks genuine on the chart.
"""

import random
import math
from datetime import datetime, timedelta
from typing import Optional


# Realistic base prices and pip sizes per pair
PAIR_CONFIG = {
    "EURUSD": {"base": 1.08440, "pip": 0.00010, "volatility": 0.0008},
    "GBPUSD": {"base": 1.26520, "pip": 0.00010, "volatility": 0.0012},
    "USDJPY": {"base": 149.830, "pip": 0.01000, "volatility": 0.12},
    "USDCHF": {"base": 0.90130, "pip": 0.00010, "volatility": 0.0007},
    "AUDUSD": {"base": 0.64860, "pip": 0.00010, "volatility": 0.0009},
    "USDCAD": {"base": 1.35630, "pip": 0.00010, "volatility": 0.0009},
    "NZDUSD": {"base": 0.60130, "pip": 0.00010, "volatility": 0.0008},
    "EURGBP": {"base": 0.85650, "pip": 0.00010, "volatility": 0.0006},
    "EURJPY": {"base": 162.290, "pip": 0.01000, "volatility": 0.14},
    "GBPJPY": {"base": 189.460, "pip": 0.01000, "volatility": 0.18},
}

# Timeframe â†’ candle duration in minutes
TIMEFRAME_MINUTES = {
    "M1":  1,
    "M5":  5,
    "M15": 15,
    "M30": 30,
    "H1":  60,
    "H4":  240,
    "D":   1440,
    "W":   10080,
}


def generate_mock_candles(
    pair: str,
    granularity: str = "M15",
    count: int = 100,
) -> list[dict]:
    """
    Generate realistic OHLCV candles for a given pair and timeframe.

    Uses a seeded Brownian motion random walk so the same pair+timeframe
    always produces the same shape (reproducible), while still looking
    like a real chart.

    Returns list of candle dicts:
    {
        "time":   "2026-03-29T10:00:00",
        "open":   1.08440,
        "high":   1.08512,
        "low":    1.08398,
        "close":  1.08487,
        "volume": 1234
    }
    """
    pair_upper = pair.upper().replace("/", "").replace("-", "")
    config = PAIR_CONFIG.get(pair_upper, {"base": 1.0, "pip": 0.0001, "volatility": 0.001})

    tf_minutes = TIMEFRAME_MINUTES.get(granularity.upper(), 15)

    # Seed with pair name for reproducibility
    rng = random.Random(hash(pair_upper + granularity) % (2**31))

    # Start time: count candles back from now
    now = datetime.utcnow().replace(second=0, microsecond=0)
    # Floor to timeframe boundary
    floored_minute = (now.minute // tf_minutes) * tf_minutes
    end_time = now.replace(minute=floored_minute % 60)
    start_time = end_time - timedelta(minutes=tf_minutes * count)

    candles = []
    price = config["base"]
    vol = config["volatility"]

    # Add a slight trend bias to make chart interesting
    trend_bias = rng.uniform(-0.0002, 0.0002)

    for i in range(count):
        candle_time = start_time + timedelta(minutes=tf_minutes * i)

        # Random walk step
        open_price = price
        move = rng.gauss(trend_bias, vol)
        close_price = round(open_price + move, 5)

        # High and low: extend beyond open/close realistically
        wick_range = abs(move) * rng.uniform(0.5, 2.5)
        high_price = round(max(open_price, close_price) + wick_range * rng.uniform(0.2, 0.8), 5)
        low_price  = round(min(open_price, close_price) - wick_range * rng.uniform(0.2, 0.8), 5)

        # Realistic volume (higher on H1/H4/D, lower on M1)
        base_volume = 500 if tf_minutes <= 5 else (2000 if tf_minutes <= 60 else 8000)
        volume = int(rng.gauss(base_volume, base_volume * 0.3))
        volume = max(100, volume)

        candles.append({
            "time":   candle_time.strftime("%Y-%m-%dT%H:%M:%S"),
            "open":   open_price,
            "high":   high_price,
            "low":    low_price,
            "close":  close_price,
            "volume": volume,
        })

        price = close_price

        # Occasional trend reversal to make chart look natural
        if rng.random() < 0.05:
            trend_bias = -trend_bias

    return candles