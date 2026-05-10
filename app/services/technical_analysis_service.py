"""
app/services/technical_analysis_service.py
Candle source priority:
  1. forex_data_service.get_ohlc()   (unwraps dict or list)
  3. Yahoo Finance                   (free, no key)
"""
from __future__ import annotations
import logging, httpx
from typing import Dict, List, Optional
logger = logging.getLogger(__name__)

def _unwrap_candles(data) -> List[dict]:
    if isinstance(data, list):
        return data
    if isinstance(data, dict):
        if "values" in data and isinstance(data["values"], list):
            return data["values"]
        if "data" in data and isinstance(data["data"], list):
            return data["data"]
    return []

async def _fetch_yahoo_closes(pair: str, interval: str = "1h", count: int = 60) -> List[float]:
    try:
        symbol = pair.replace("/", "") + "=X"
        interval_map = {"1h": ("60d","1h"), "15m": ("7d","15m"), "4h": ("60d","1h"), "1d": ("1y","1d")}
        yrange, yinterval = interval_map.get(interval, ("60d","1h"))
        url = f"https://query1.finance.yahoo.com/v8/finance/chart/{symbol}"
        async with httpx.AsyncClient(timeout=10.0) as c:
            r = await c.get(url, params={"interval": yinterval, "range": yrange, "events": "history"},
                            headers={"User-Agent": "Mozilla/5.0"})
            r.raise_for_status()
            body = r.json()
        result = body.get("chart", {}).get("result", [])
        if not result:
            return []
        closes_raw = result[0].get("indicators", {}).get("quote", [{}])[0].get("close", [])
        closes = [float(c) for c in closes_raw if c is not None][-count:]
        if len(closes) >= 30:
            logger.info("Yahoo Finance: %d closes for %s", len(closes), symbol)
            return closes
    except Exception as e:
        logger.debug("Yahoo Finance failed for %s: %s", pair, e)
    return []

async def _fetch_closes(pair: str, interval: str = "1h", count: int = 60) -> List[float]:
    symbol_raw   = pair.replace("/", "")
    symbol_slash = pair if "/" in pair else (pair[:3]+"/"+pair[3:] if len(pair)==6 else pair)
    try:
        from app.services.forex_data_service import get_ohlc
        raw = await get_ohlc(symbol_raw, interval=interval, outputsize=count)
        candles = _unwrap_candles(raw)
        if len(candles) >= 30:
            closes = [float(c["close"]) for c in candles if c.get("close") is not None]
            if len(closes) >= 30:
                return closes
    except Exception as e:
        logger.debug("TA: forex_data_service failed for %s: %s", pair, e)
    try:
        raw = await fetch_timeseries(symbol_slash, interval=interval, outputsize=count)
        candles = _unwrap_candles(raw)
        if len(candles) >= 30:
            closes = [float(c["close"]) for c in candles if c.get("close") is not None]
            if len(closes) >= 30:
                return closes
    except Exception as e:
        pass
    closes = await _fetch_yahoo_closes(symbol_slash, interval=interval, count=count)
    if closes:
        return closes
    logger.warning("TA: no candle data for %s", pair)
    return []
def _compute_rsi(closes: List[float], period: int = 14) -> Optional[float]:
    if len(closes) < period + 1:
        return None
    gains, losses = [], []
    for i in range(1, len(closes)):
        delta = closes[i] - closes[i-1]
        gains.append(max(delta, 0))
        losses.append(max(-delta, 0))
    avg_gain = sum(gains[-period:]) / period
    avg_loss = sum(losses[-period:]) / period
    if avg_loss == 0:
        return 100.0
    return round(100 - (100 / (1 + avg_gain/avg_loss)), 2)

def _compute_macd(closes: List[float], fast: int=12, slow: int=26, signal: int=9) -> Optional[Dict]:
    if len(closes) < slow + signal:
        return None
    def ema(data, period):
        k = 2/(period+1)
        r = [sum(data[:period])/period]
        for p in data[period:]:
            r.append(p*k + r[-1]*(1-k))
        return r
    ef, es = ema(closes, fast), ema(closes, slow)
    ml = min(len(ef), len(es))
    macd_line = [ef[-(ml-i)] - es[-(ml-i)] for i in range(ml)]
    if len(macd_line) < signal:
        return None
    k = 2/(signal+1)
    sl = [sum(macd_line[:signal])/signal]
    for v in macd_line[signal:]:
        sl.append(v*k + sl[-1]*(1-k))
    mv, sv = macd_line[-1], sl[-1]
    hist = mv - sv
    return {"macd": round(mv,6), "signal": round(sv,6), "histogram": round(hist,6),
            "bias": "bullish" if hist > 0 else "bearish"}

def _rsi_bias(rsi: float) -> str:
    if rsi >= 70: return "overbought"
    if rsi <= 30: return "oversold"
    if rsi >= 55: return "bullish"
    if rsi <= 45: return "bearish"
    return "neutral"

async def get_technical_indicators(pair: str) -> Dict:
    if "/" not in pair and len(pair) == 6:
        pair = pair[:3]+"/"+pair[3:]
    closes = await _fetch_closes(pair, interval="1h", count=60)
    if len(closes) < 30:
        return {"rsi": None, "macd": None, "technical_bias": "neutral",
                "indicator_tags": ["Insufficient data"], "available": False}
    rsi  = _compute_rsi(closes)
    macd = _compute_macd(closes)
    tags, votes = [], []
    if rsi is not None:
        rb = _rsi_bias(rsi)
        tags.append(f"RSI {rsi:.0f}")
        if rb == "overbought":   tags.append("Overbought"); votes.append("bearish")
        elif rb == "oversold":   tags.append("Oversold");   votes.append("bullish")
        elif rb in ("bullish","bearish"): votes.append(rb)
    if macd:
        tags.append(f"MACD {macd['bias'].title()}")
        votes.append(macd["bias"])
    bull, bear = votes.count("bullish"), votes.count("bearish")
    bias = "bullish" if bull > bear else "bearish" if bear > bull else "neutral"
    return {"rsi": rsi, "macd": macd, "technical_bias": bias, "indicator_tags": tags, "available": True}


