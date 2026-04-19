"""
Backend/scripts/data_collector.py
Phase 5 — ML Data Collection

Fetches OHLC + technical indicator data from Twelve Data and saves it
to a local CSV file for model training.

Usage:
    cd Backend
    python scripts/data_collector.py

Output:
    Backend/ml_data/training_data.csv

Columns:
    pair, timestamp, open, high, low, close, volume,
    rsi, macd, macd_signal, macd_hist,
    ema_20, ema_50, bb_upper, bb_lower,
    label  (1=BUY, -1=SELL, 0=HOLD — computed from next-candle return)
"""

import os
import sys
import csv
import json
import time
import logging
import asyncio
from datetime import datetime, timezone
from pathlib import Path

import httpx
from dotenv import load_dotenv

# ── Setup ─────────────────────────────────────────────────────────────────────

# Load .env from Backend/
load_dotenv(dotenv_path=Path(__file__).resolve().parents[1] / ".env")

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(message)s",
)
logger = logging.getLogger("data_collector")

TWELVE_DATA_API_KEY = os.getenv("TWELVE_DATA_API_KEY", "")
TWELVE_DATA_BASE    = "https://api.twelvedata.com"

OUTPUT_DIR  = Path(__file__).resolve().parents[1] / "ml_data"
OUTPUT_FILE = OUTPUT_DIR / "training_data.csv"

PAIRS = [
    "EUR/USD", "GBP/USD", "USD/JPY",
    "AUD/USD", "USD/CAD", "USD/CHF",
]

INTERVAL   = "1h"      # 1h candles — good balance of signal vs noise
OUTPUTSIZE = 500       # 500 candles per pair (~20 days of 1h data)

# Label threshold: if next-candle return > +0.05% → BUY, < -0.05% → SELL, else HOLD
LABEL_THRESHOLD = 0.0005


# ── Helpers ───────────────────────────────────────────────────────────────────

def _label(returns: list[float]) -> list[int]:
    """Convert a list of next-candle returns to BUY/SELL/HOLD labels."""
    labels = []
    for r in returns:
        if r > LABEL_THRESHOLD:
            labels.append(1)    # BUY
        elif r < -LABEL_THRESHOLD:
            labels.append(-1)   # SELL
        else:
            labels.append(0)    # HOLD
    return labels


async def _fetch_time_series(client: httpx.AsyncClient, symbol: str) -> list[dict]:
    """Fetch OHLCV time series from Twelve Data."""
    url = f"{TWELVE_DATA_BASE}/time_series"
    params = {
        "symbol":     symbol,
        "interval":   INTERVAL,
        "outputsize": OUTPUTSIZE,
        "apikey":     TWELVE_DATA_API_KEY,
        "format":     "JSON",
    }
    resp = await client.get(url, params=params, timeout=15.0)
    resp.raise_for_status()
    data = resp.json()

    if data.get("status") == "error":
        raise ValueError(f"Twelve Data error for {symbol}: {data.get('message')}")

    values = data.get("values", [])
    # Twelve Data returns newest-first — reverse to chronological order
    return list(reversed(values))


async def _fetch_rsi(client: httpx.AsyncClient, symbol: str) -> list[dict]:
    """Fetch RSI(14) from Twelve Data."""
    url = f"{TWELVE_DATA_BASE}/rsi"
    params = {
        "symbol":     symbol,
        "interval":   INTERVAL,
        "time_period": 14,
        "outputsize": OUTPUTSIZE,
        "apikey":     TWELVE_DATA_API_KEY,
        "format":     "JSON",
    }
    resp = await client.get(url, params=params, timeout=15.0)
    resp.raise_for_status()
    data = resp.json()
    if data.get("status") == "error":
        logger.warning("RSI fetch failed for %s: %s", symbol, data.get("message"))
        return []
    return list(reversed(data.get("values", [])))


async def _fetch_macd(client: httpx.AsyncClient, symbol: str) -> list[dict]:
    """Fetch MACD(12,26,9) from Twelve Data."""
    url = f"{TWELVE_DATA_BASE}/macd"
    params = {
        "symbol":       symbol,
        "interval":     INTERVAL,
        "fast_period":  12,
        "slow_period":  26,
        "signal_period": 9,
        "outputsize":   OUTPUTSIZE,
        "apikey":       TWELVE_DATA_API_KEY,
        "format":       "JSON",
    }
    resp = await client.get(url, params=params, timeout=15.0)
    resp.raise_for_status()
    data = resp.json()
    if data.get("status") == "error":
        logger.warning("MACD fetch failed for %s: %s", symbol, data.get("message"))
        return []
    return list(reversed(data.get("values", [])))


async def _fetch_ema(client: httpx.AsyncClient, symbol: str, period: int) -> list[dict]:
    """Fetch EMA for a given period."""
    url = f"{TWELVE_DATA_BASE}/ema"
    params = {
        "symbol":      symbol,
        "interval":    INTERVAL,
        "time_period": period,
        "outputsize":  OUTPUTSIZE,
        "apikey":      TWELVE_DATA_API_KEY,
        "format":      "JSON",
    }
    resp = await client.get(url, params=params, timeout=15.0)
    resp.raise_for_status()
    data = resp.json()
    if data.get("status") == "error":
        logger.warning("EMA(%d) fetch failed for %s: %s", period, symbol, data.get("message"))
        return []
    return list(reversed(data.get("values", [])))


async def _fetch_bbands(client: httpx.AsyncClient, symbol: str) -> list[dict]:
    """Fetch Bollinger Bands(20,2)."""
    url = f"{TWELVE_DATA_BASE}/bbands"
    params = {
        "symbol":      symbol,
        "interval":    INTERVAL,
        "time_period": 20,
        "outputsize":  OUTPUTSIZE,
        "apikey":      TWELVE_DATA_API_KEY,
        "format":      "JSON",
    }
    resp = await client.get(url, params=params, timeout=15.0)
    resp.raise_for_status()
    data = resp.json()
    if data.get("status") == "error":
        logger.warning("BBands fetch failed for %s: %s", symbol, data.get("message"))
        return []
    return list(reversed(data.get("values", [])))


def _align_by_datetime(
    ohlcv: list[dict],
    rsi:   list[dict],
    macd:  list[dict],
    ema20: list[dict],
    ema50: list[dict],
    bb:    list[dict],
) -> list[dict]:
    """
    Align all indicator series to the OHLCV timestamps.
    Twelve Data indicators may have fewer rows (warm-up period).
    We use a dict keyed by datetime string for O(1) lookup.
    """
    rsi_map   = {r["datetime"]: r for r in rsi}
    macd_map  = {m["datetime"]: m for m in macd}
    ema20_map = {e["datetime"]: e for e in ema20}
    ema50_map = {e["datetime"]: e for e in ema50}
    bb_map    = {b["datetime"]: b for b in bb}

    rows = []
    for candle in ohlcv:
        dt = candle["datetime"]
        row = {
            "datetime":  dt,
            "open":      float(candle.get("open",  0)),
            "high":      float(candle.get("high",  0)),
            "low":       float(candle.get("low",   0)),
            "close":     float(candle.get("close", 0)),
            "volume":    float(candle.get("volume", 0) or 0),
            "rsi":       float(rsi_map[dt]["rsi"])          if dt in rsi_map   else None,
            "macd":      float(macd_map[dt]["macd"])        if dt in macd_map  else None,
            "macd_signal": float(macd_map[dt]["macd_signal"]) if dt in macd_map else None,
            "macd_hist": float(macd_map[dt]["macd_hist"])   if dt in macd_map  else None,
            "ema_20":    float(ema20_map[dt]["ema"])        if dt in ema20_map else None,
            "ema_50":    float(ema50_map[dt]["ema"])        if dt in ema50_map else None,
            "bb_upper":  float(bb_map[dt]["upper_band"])    if dt in bb_map    else None,
            "bb_lower":  float(bb_map[dt]["lower_band"])    if dt in bb_map    else None,
        }
        rows.append(row)
    return rows


async def collect_pair(client: httpx.AsyncClient, symbol: str) -> list[dict]:
    """Collect all data for one pair and return labelled rows."""
    logger.info("Collecting %s …", symbol)

    # Fetch all series (rate-limit: 8 req/min on free tier — add small delays)
    ohlcv = await _fetch_time_series(client, symbol)
    await asyncio.sleep(1)
    rsi   = await _fetch_rsi(client, symbol)
    await asyncio.sleep(1)
    macd  = await _fetch_macd(client, symbol)
    await asyncio.sleep(1)
    ema20 = await _fetch_ema(client, symbol, 20)
    await asyncio.sleep(1)
    ema50 = await _fetch_ema(client, symbol, 50)
    await asyncio.sleep(1)
    bb    = await _fetch_bbands(client, symbol)
    await asyncio.sleep(2)   # extra pause between pairs

    if not ohlcv:
        logger.warning("No OHLCV data for %s — skipping", symbol)
        return []

    rows = _align_by_datetime(ohlcv, rsi, macd, ema20, ema50, bb)

    # Compute next-candle return for labelling
    closes = [r["close"] for r in rows]
    returns = []
    for i in range(len(closes) - 1):
        ret = (closes[i + 1] - closes[i]) / closes[i] if closes[i] != 0 else 0.0
        returns.append(ret)
    returns.append(0.0)   # last candle has no "next" — label as HOLD

    labels = _label(returns)

    pair_internal = symbol.replace("/", "_")
    for i, row in enumerate(rows):
        row["pair"]   = pair_internal
        row["label"]  = labels[i]
        row["return"] = round(returns[i], 8)

    logger.info(
        "  %s: %d rows | BUY=%d SELL=%d HOLD=%d",
        symbol,
        len(rows),
        labels.count(1),
        labels.count(-1),
        labels.count(0),
    )
    return rows


# ── Main ──────────────────────────────────────────────────────────────────────

async def main():
    if not TWELVE_DATA_API_KEY:
        logger.error("TWELVE_DATA_API_KEY is not set in .env — aborting.")
        sys.exit(1)

    OUTPUT_DIR.mkdir(parents=True, exist_ok=True)

    all_rows: list[dict] = []

    async with httpx.AsyncClient() as client:
        for symbol in PAIRS:
            try:
                rows = await collect_pair(client, symbol)
                all_rows.extend(rows)
            except Exception as e:
                logger.error("Failed to collect %s: %s", symbol, e)

    if not all_rows:
        logger.error("No data collected — check API key and network.")
        sys.exit(1)

    # Write CSV
    fieldnames = [
        "pair", "datetime", "open", "high", "low", "close", "volume",
        "rsi", "macd", "macd_signal", "macd_hist",
        "ema_20", "ema_50", "bb_upper", "bb_lower",
        "return", "label",
    ]

    with open(OUTPUT_FILE, "w", newline="", encoding="utf-8") as f:
        writer = csv.DictWriter(f, fieldnames=fieldnames, extrasaction="ignore")
        writer.writeheader()
        writer.writerows(all_rows)

    logger.info("=" * 60)
    logger.info("Data collection complete!")
    logger.info("  Rows written : %d", len(all_rows))
    logger.info("  Output file  : %s", OUTPUT_FILE)
    logger.info("  Next step    : python scripts/train_model.py")
    logger.info("=" * 60)


if __name__ == "__main__":
    asyncio.run(main())
