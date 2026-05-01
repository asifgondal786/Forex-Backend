"""
app/services/nlp_command_service.py
Consolidated NLP service — replaces both old nlp_command_service.py and natural_language_service.py.

Flow:
  1. OpenAI (GPT-4o-mini) parses the command → structured JSON
  2. If OpenAI unavailable or confidence < 0.6 → regex fallback
  3. DeepSeek validates OPEN_TRADE / CLOSE_TRADE intents against live market

Swap to Claude later: change claude_client.py only. This file never changes.
"""
from __future__ import annotations

import logging
import re
from typing import Any, Optional

from app.ai.openai_client import claude_client          # OpenAI today, Claude tomorrow
from app.ai.deepseek_client import deepseek_client      # Market analysis / validation

logger = logging.getLogger(__name__)

# ── Pair aliases for regex fallback ──────────────────────────────────────────
_PAIR_ALIASES: dict[str, str] = {
    "eurusd": "EUR_USD", "eur/usd": "EUR_USD", "eur usd": "EUR_USD", "euro dollar": "EUR_USD",
    "gbpusd": "GBP_USD", "gbp/usd": "GBP_USD", "gbp usd": "GBP_USD", "cable": "GBP_USD",
    "usdjpy": "USD_JPY", "usd/jpy": "USD_JPY", "usd jpy": "USD_JPY", "dollar yen": "USD_JPY",
    "audusd": "AUD_USD", "aud/usd": "AUD_USD", "aussie": "AUD_USD",
    "usdcad": "USD_CAD", "usd/cad": "USD_CAD", "loonie": "USD_CAD",
    "usdchf": "USD_CHF", "usd/chf": "USD_CHF", "swissy": "USD_CHF",
    "nzdusd": "NZD_USD", "nzd/usd": "NZD_USD", "kiwi": "NZD_USD",
}

_BUY_WORDS    = {"buy", "long", "purchase", "open buy", "go long", "bullish"}
_SELL_WORDS   = {"sell", "short", "open sell", "go short", "bearish"}
_CLOSE_WORDS  = {"close", "exit", "close trade", "close position", "exit trade"}
_SIGNAL_WORDS = {"signal", "signals", "analyse", "analyze", "analysis", "what do you think", "trade idea"}
_NEWS_WORDS   = {"news", "headlines", "events", "calendar", "what's happening", "market update"}
_RISK_WORDS   = {"risk", "kelly", "position size", "lot size", "how much to trade"}
_PERF_WORDS   = {"balance", "account", "performance", "profit", "loss", "p&l", "stats"}
_STOP_WORDS   = {"stop all", "kill switch", "close everything", "halt", "freeze all"}
_ALERT_WORDS  = {"alert", "notify", "notify me", "ping me"}


# ── Regex helpers ─────────────────────────────────────────────────────────────
def _extract_pair(text: str) -> Optional[str]:
    lower = text.lower()
    for alias, pair in _PAIR_ALIASES.items():
        if alias in lower:
            return pair
    m = re.search(r'\b([A-Z]{3})[/_]?([A-Z]{3})\b', text.upper())
    return f"{m.group(1)}_{m.group(2)}" if m else None


def _extract_risk_pct(text: str) -> Optional[float]:
    m = re.search(r'(\d+(?:\.\d+)?)\s*%', text)
    if m:
        return float(m.group(1)) / 100
    m = re.search(r'(\d+(?:\.\d+)?)\s*percent', text.lower())
    return float(m.group(1)) / 100 if m else None


def _extract_price(text: str) -> Optional[float]:
    m = re.search(r'\b(\d{1,2}\.\d{2,5})\b', text)  # Forex price pattern e.g. 1.0825
    return float(m.group(1)) if m else None


# ── Regex fallback parser ─────────────────────────────────────────────────────
def _regex_parse(text: str, account_balance: float) -> dict[str, Any]:
    """Pure regex fallback when OpenAI is unavailable."""
    lower = text.lower().strip()

    is_buy    = any(k in lower for k in _BUY_WORDS)
    is_sell   = any(k in lower for k in _SELL_WORDS)
    is_close  = any(k in lower for k in _CLOSE_WORDS)
    is_signal = any(k in lower for k in _SIGNAL_WORDS)
    is_news   = any(k in lower for k in _NEWS_WORDS)
    is_risk   = any(k in lower for k in _RISK_WORDS)
    is_perf   = any(k in lower for k in _PERF_WORDS)
    is_stop   = any(k in lower for k in _STOP_WORDS)
    is_alert  = any(k in lower for k in _ALERT_WORDS)

    pair     = _extract_pair(text)
    risk_pct = _extract_risk_pct(text) or 0.01
    price    = _extract_price(text)

    if is_stop:
        return {"intent": "STOP_ALL", "pair": None, "confidence": 0.95,
                "requires_confirmation": True,
                "response": "⚠️ Kill switch ready. Confirm to close all trades."}

    if (is_buy or is_sell) and not is_close:
        direction   = "BUY" if is_buy else "SELL"
        risk_amount = round(risk_pct * account_balance, 2)
        return {
            "intent": "OPEN_TRADE", "direction": direction,
            "pair": pair or "EUR_USD", "risk_pct": round(risk_pct, 4),
            "entry_price": price, "stop_loss": None, "take_profit": None,
            "confidence": 0.75 if pair else 0.5,
            "requires_confirmation": True,
            "response": (
                f"Opening {direction} on {(pair or 'EUR_USD').replace('_', '/')} "
                f"with {round(risk_pct * 100, 1)}% risk (${risk_amount}). Confirm?"
            ),
        }

    if is_close:
        return {"intent": "CLOSE_TRADE", "pair": pair, "confidence": 0.8,
                "requires_confirmation": True,
                "response": f"Closing {'your ' + pair.replace('_', '/') + ' position' if pair else 'trade'}. Confirm?"}

    if is_alert:
        return {"intent": "SET_ALERT", "pair": pair, "entry_price": price,
                "confidence": 0.8 if pair else 0.5, "requires_confirmation": False,
                "response": f"Setting alert for {pair.replace('_', '/') if pair else 'pair'}..."}

    if is_signal:
        return {"intent": "GET_SIGNAL", "pair": pair, "confidence": 0.85,
                "requires_confirmation": False,
                "response": f"Fetching {'signal for ' + pair.replace('_', '/') if pair else 'latest signals'}..."}

    if is_news:
        return {"intent": "GET_NEWS", "pair": pair, "confidence": 0.85,
                "requires_confirmation": False,
                "response": "Fetching latest market news and economic events..."}

    if is_risk:
        return {"intent": "GET_RISK", "pair": pair, "confidence": 0.85,
                "requires_confirmation": False,
                "response": "Calculating optimal position size using Kelly Criterion..."}

    if is_perf:
        return {"intent": "GET_PERFORMANCE", "confidence": 0.9,
                "requires_confirmation": False,
                "response": "Fetching your paper trading performance stats..."}

    # Unknown
    return {
        "intent": "CHAT", "confidence": 0.3,
        "requires_confirmation": False,
        "response": "Try: 'Buy EUR/USD with 1% risk' or 'Show me GBP/USD signal'",
    }


# ── DeepSeek validation for trade intents ────────────────────────────────────
_DEEPSEEK_VALIDATE_PROMPT = """You are a forex risk validator. Given this parsed trade command, 
check if the direction makes sense based on general market principles.
Return ONLY JSON: {{"approved": true/false, "reason": "one sentence", "adjusted_risk_pct": float or null}}
Do not suggest specific prices. Keep reason under 80 characters.
Command: {command}"""


async def _deepseek_validate(parsed: dict[str, Any]) -> dict[str, Any]:
    """Ask DeepSeek to sanity-check a trade intent."""
    if not deepseek_client.available:
        return {"approved": True, "reason": "DeepSeek unavailable — skipping validation"}
    try:
        result = await deepseek_client.chat_completion_json(
            messages=[{"role": "user", "content": _DEEPSEEK_VALIDATE_PROMPT.format(command=parsed)}],
            temperature=0.1,
            max_tokens=150,
            fallback={"approved": True, "reason": "Validation skipped"},
        )
        return result
    except Exception as e:
        logger.warning("DeepSeek validation failed: %s", e)
        return {"approved": True, "reason": "Validation unavailable"}


# ── Main public function ──────────────────────────────────────────────────────
async def process_nlp_command(
    text: str,
    account_balance: float = 10_000.0,
    validate_trades: bool = True,
) -> dict[str, Any]:
    """
    Full NLP pipeline:
      1. OpenAI parses natural language → structured JSON
      2. Regex fallback if OpenAI fails or low confidence
      3. DeepSeek validates OPEN_TRADE intents

    Returns final enriched command dict ready for the router to return to Flutter.
    """
    parsed: dict[str, Any] = {}

    # ── Step 1: OpenAI parse ──────────────────────────────────────────────────
    if claude_client.available:
        try:
            parsed = await claude_client.parse_trading_command(text)
            logger.info("OpenAI parsed intent=%s confidence=%s",
                        parsed.get("intent"), parsed.get("confidence"))
        except Exception as e:
            logger.warning("OpenAI NLP failed, falling back to regex: %s", e)
            parsed = {}

    # ── Step 2: Regex fallback ────────────────────────────────────────────────
    if not parsed or parsed.get("confidence", 0) < 0.6:
        logger.info("Using regex fallback for: %r", text)
        regex_result = _regex_parse(text, account_balance)
        # Merge: keep OpenAI fields if they exist but supplement with regex
        parsed = {**regex_result, **{k: v for k, v in parsed.items() if v is not None}}
        parsed["fallback_used"] = True

    # ── Step 3: DeepSeek validate trade intents ───────────────────────────────
    validation: dict[str, Any] = {}
    if validate_trades and parsed.get("intent") == "OPEN_TRADE":
        validation = await _deepseek_validate(parsed)
        if not validation.get("approved", True):
            parsed["response"] = f"⚠️ Trade flagged: {validation.get('reason')}. Proceed anyway?"
        if validation.get("adjusted_risk_pct"):
            parsed["risk_pct"] = validation["adjusted_risk_pct"]
            parsed["risk_usd"] = round(validation["adjusted_risk_pct"] * account_balance, 2)

    return {
        **parsed,
        "original_text": text,
        "validation": validation,
        "risk_usd": round((parsed.get("risk_pct") or 0.01) * account_balance, 2),
    }
