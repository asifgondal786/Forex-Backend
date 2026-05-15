"""
app/services/signal_engine.py
Phase 2B — Multi-Model Consensus Engine

Flow:
  1. Internal TA (Yahoo/forex_data_service) already computed RSI + MACD
     inside signal_service.py → passed in as `internal_ta`
  2. Alpha Vantage fetches independent RSI(14) + EMA(20) + EMA(50)
  3. Each indicator votes BUY / SELL / HOLD
  4. Votes are weighted and combined into a consensus_score
  5. If consensus_score < MIN_CONSENSUS → action downgraded to HOLD
  6. Final score replaces the fused_confidence from signal_service.py

Pair format accepted: "EUR/USD", "EURUSD", "EUR_USD"
"""

from __future__ import annotations

import logging
import os
from typing import Optional

import httpx

logger = logging.getLogger(__name__)

# ── Config ────────────────────────────────────────────────────────────────────
AV_KEY           = os.getenv("ALPHAVANTAGE_API_KEY", "")
AV_BASE          = "https://www.alphavantage.co/query"
MIN_CONSENSUS    = 0.55          # below this → downgrade to HOLD
AV_TIMEOUT       = 12.0          # seconds per AV call
MAX_AV_CALLS     = 3             # RSI + EMA20 + EMA50

# Weights for each voting source  (must sum to 1.0)
WEIGHT_INTERNAL_RSI  = 0.20
WEIGHT_INTERNAL_MACD = 0.20
WEIGHT_AV_RSI        = 0.25
WEIGHT_AV_EMA        = 0.35      # EMA20 vs EMA50 crossover — strongest signal


# ── Alpha Vantage helpers ─────────────────────────────────────────────────────

def _normalise_pair(pair: str) -> str:
    """Return 'EURUSD' from any of EUR/USD | EUR_USD | EURUSD."""
    return pair.replace("/", "").replace("_", "").upper()


async def _av_get(params: dict) -> dict:
    """Single Alpha Vantage GET — returns parsed JSON or {}."""
    if not AV_KEY:
        logger.warning("signal_engine: ALPHAVANTAGE_API_KEY not set — AV skipped")
        return {}
    try:
        async with httpx.AsyncClient(timeout=AV_TIMEOUT) as client:
            r = await client.get(AV_BASE, params={**params, "apikey": AV_KEY})
            r.raise_for_status()
            data = r.json()
            # AV returns {"Note": "..."} when rate-limited
            if "Note" in data or "Information" in data:
                logger.warning("signal_engine: AV rate limit hit — %s", list(data.keys()))
                return {}
            return data
    except Exception as e:
        logger.warning("signal_engine: AV request failed: %s", e)
        return {}


async def _fetch_av_rsi(symbol: str, interval: str = "60min") -> Optional[float]:
    """
    Fetch RSI(14) from Alpha Vantage for the given forex symbol.
    Returns the latest RSI value or None on failure.
    """
    data = await _av_get({
        "function":   "RSI",
        "symbol":     symbol,
        "interval":   interval,
        "time_period": 14,
        "series_type": "close",
    })
    try:
        meta    = data.get("Technical Analysis: RSI", {})
        latest  = next(iter(meta.values()))        # most recent timestamp first
        return float(latest["RSI"])
    except Exception:
        return None


async def _fetch_av_ema(symbol: str, period: int, interval: str = "60min") -> Optional[float]:
    """
    Fetch EMA(period) from Alpha Vantage.
    Returns the latest EMA value or None.
    """
    data = await _av_get({
        "function":    "EMA",
        "symbol":      symbol,
        "interval":    interval,
        "time_period": period,
        "series_type": "close",
    })
    try:
        meta   = data.get("Technical Analysis: EMA", {})
        latest = next(iter(meta.values()))
        return float(latest["EMA"])
    except Exception:
        return None


# ── Voting logic ──────────────────────────────────────────────────────────────

def _rsi_vote(rsi: Optional[float], action: str) -> float:
    """
    Returns a weighted directional score in [-1, +1].
    +1 = strongly confirms action, -1 = strongly contradicts.
    """
    if rsi is None:
        return 0.0                          # abstain

    action = action.upper()

    if rsi <= 30:       direction = "BUY"   # oversold → bullish
    elif rsi >= 70:     direction = "SELL"  # overbought → bearish
    elif rsi >= 55:     direction = "BUY"   # mild bullish
    elif rsi <= 45:     direction = "SELL"  # mild bearish
    else:               direction = "HOLD"  # neutral zone

    if direction == "HOLD":
        return 0.0
    if direction == action:
        # How strongly? Scale 0.5→1.0 based on extremity
        if rsi <= 30 or rsi >= 70:
            return 1.0                      # extreme → full weight
        return 0.6                          # mild → partial weight
    return -0.6                             # contradicts action


def _ema_vote(ema20: Optional[float], ema50: Optional[float], action: str) -> float:
    """
    EMA crossover vote.
    EMA20 > EMA50 → uptrend (BUY bias)
    EMA20 < EMA50 → downtrend (SELL bias)
    Returns score in [-1, +1].
    """
    if ema20 is None or ema50 is None:
        return 0.0

    action = action.upper()
    gap    = abs(ema20 - ema50) / ema50     # relative gap

    if ema20 > ema50:
        direction = "BUY"
    elif ema20 < ema50:
        direction = "SELL"
    else:
        return 0.0

    strength = min(gap / 0.002, 1.0)        # 0.2% gap = full strength

    if direction == action:
        return round(0.5 + 0.5 * strength, 3)   # 0.5 → 1.0
    return round(-(0.5 + 0.5 * strength), 3)    # -0.5 → -1.0


def _macd_vote(macd_data: Optional[dict], action: str) -> float:
    """Convert existing internal MACD dict to a vote score."""
    if not macd_data:
        return 0.0
    bias = macd_data.get("bias", "neutral")
    hist = abs(macd_data.get("histogram", 0))

    if bias == "bullish":
        direction = "BUY"
    elif bias == "bearish":
        direction = "SELL"
    else:
        return 0.0

    # Scale by histogram magnitude (cap at 0.0005 for forex)
    strength = min(hist / 0.0005, 1.0)
    score    = round(0.5 + 0.5 * strength, 3)
    return score if direction == action.upper() else -score


# ── Main consensus function ───────────────────────────────────────────────────

async def consensus_check(
    pair:        str,
    action:      str,
    base_confidence: float,
    internal_ta: dict,
) -> dict:
    """
    Run multi-model consensus and return an updated confidence + metadata.

    Parameters
    ----------
    pair             : e.g. "EUR/USD"
    action           : "BUY" | "SELL" | "HOLD"
    base_confidence  : fused_confidence from signal_service._fuse_confidence()
    internal_ta      : dict returned by get_technical_indicators()
                       keys: rsi, macd, technical_bias, available

    Returns
    -------
    {
        "consensus_score":  float,       # 0.0 – 1.0  (replaces confidence)
        "action":           str,         # may be downgraded to "HOLD"
        "av_rsi":           float|None,
        "av_ema20":         float|None,
        "av_ema50":         float|None,
        "av_available":     bool,
        "votes": {
            "internal_rsi":  float,
            "internal_macd": float,
            "av_rsi":        float,
            "av_ema":        float,
        },
        "downgraded":       bool,
        "reason":           str,
    }
    """
    action = action.upper()
    symbol = _normalise_pair(pair)       # "EURUSD"

    # ── 1. Fetch Alpha Vantage data (3 async calls) ───────────────────────────
    av_rsi  = None
    av_ema20 = None
    av_ema50 = None
    av_available = False

    if AV_KEY and action != "HOLD":
        try:
            import asyncio
            av_rsi, av_ema20, av_ema50 = await asyncio.gather(
                _fetch_av_rsi(symbol),
                _fetch_av_ema(symbol, period=20),
                _fetch_av_ema(symbol, period=50),
                return_exceptions=True,
            )
            # asyncio.gather with return_exceptions returns Exception objects on failure
            if isinstance(av_rsi,   Exception): av_rsi   = None
            if isinstance(av_ema20, Exception): av_ema20 = None
            if isinstance(av_ema50, Exception): av_ema50 = None

            av_available = any(v is not None for v in [av_rsi, av_ema20, av_ema50])
            if av_available:
                logger.info(
                    "signal_engine: AV data for %s | RSI=%.1f EMA20=%.5f EMA50=%.5f",
                    symbol,
                    av_rsi   or 0,
                    av_ema20 or 0,
                    av_ema50 or 0,
                )
        except Exception as e:
            logger.warning("signal_engine: AV gather failed: %s", e)

    # ── 2. Compute votes ──────────────────────────────────────────────────────
    internal_rsi  = internal_ta.get("rsi")
    internal_macd = internal_ta.get("macd")

    vote_internal_rsi  = _rsi_vote(internal_rsi,  action)
    vote_internal_macd = _macd_vote(internal_macd, action)
    vote_av_rsi        = _rsi_vote(av_rsi,         action)
    vote_av_ema        = _ema_vote(av_ema20, av_ema50, action)

    logger.debug(
        "signal_engine votes | int_rsi=%.2f int_macd=%.2f av_rsi=%.2f av_ema=%.2f",
        vote_internal_rsi, vote_internal_macd, vote_av_rsi, vote_av_ema,
    )

    # ── 3. Weighted consensus score ───────────────────────────────────────────
    # Each vote is in [-1, +1].  Weight × vote → contribution.
    # Sum contributions → raw_score in [-1, +1].
    # Map to [0, 1] → consensus_score.
    # If AV data unavailable, redistribute its weight to internal indicators.

    if av_available:
        w_int_rsi  = WEIGHT_INTERNAL_RSI
        w_int_macd = WEIGHT_INTERNAL_MACD
        w_av_rsi   = WEIGHT_AV_RSI
        w_av_ema   = WEIGHT_AV_EMA
    else:
        # AV unavailable — fall back to internal-only, scale up weights
        total_internal = WEIGHT_INTERNAL_RSI + WEIGHT_INTERNAL_MACD
        w_int_rsi  = WEIGHT_INTERNAL_RSI  / total_internal
        w_int_macd = WEIGHT_INTERNAL_MACD / total_internal
        w_av_rsi   = 0.0
        w_av_ema   = 0.0
        logger.info("signal_engine: AV unavailable — using internal TA only")

    raw_score = (
        w_int_rsi  * vote_internal_rsi  +
        w_int_macd * vote_internal_macd +
        w_av_rsi   * vote_av_rsi        +
        w_av_ema   * vote_av_ema
    )

    # Blend with base_confidence (50/50).  raw_score mapped [−1,+1] → [0,1].
    indicator_score  = (raw_score + 1) / 2          # 0.0 → 1.0
    consensus_score  = round(
        0.50 * base_confidence + 0.50 * indicator_score, 3
    )

    # ── 4. Downgrade if below threshold ───────────────────────────────────────
    downgraded = False
    reason     = "Consensus passed"

    if action == "HOLD":
        # HOLD signals don't need consensus gating
        consensus_score = base_confidence
        reason = "HOLD signal — consensus not applied"
    elif consensus_score < MIN_CONSENSUS:
        downgraded = True
        action     = "HOLD"
        reason     = (
            f"Consensus {consensus_score:.0%} below threshold {MIN_CONSENSUS:.0%} "
            f"— downgraded to HOLD"
        )
        logger.info("signal_engine: %s %s DOWNGRADED to HOLD (score=%.3f)", pair, action, consensus_score)
    else:
        reason = (
            f"Consensus {consensus_score:.0%} ≥ {MIN_CONSENSUS:.0%} — signal confirmed"
        )

    logger.info(
        "signal_engine: %s | action=%s base=%.2f indicator=%.2f consensus=%.2f av=%s downgraded=%s",
        pair, action, base_confidence, indicator_score, consensus_score,
        av_available, downgraded,
    )

    return {
        "consensus_score": consensus_score,
        "action":          action,
        "av_rsi":          round(av_rsi, 2)   if av_rsi   is not None else None,
        "av_ema20":        round(av_ema20, 5) if av_ema20 is not None else None,
        "av_ema50":        round(av_ema50, 5) if av_ema50 is not None else None,
        "av_available":    av_available,
        "votes": {
            "internal_rsi":  round(vote_internal_rsi,  3),
            "internal_macd": round(vote_internal_macd, 3),
            "av_rsi":        round(vote_av_rsi,        3),
            "av_ema":        round(vote_av_ema,        3),
        },
        "downgraded": downgraded,
        "reason":     reason,
    }