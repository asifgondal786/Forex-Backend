"""
app/services/nlp_command_service.py
Phase 7 - NLP Voice Copilot
Parses natural language trading commands into structured actions.
"Open a buy on GBP/USD with 1% risk" â†’ {action: BUY, pair: GBP_USD, risk_pct: 0.01}
"""
from __future__ import annotations

import logging
import re
from typing import Dict, Optional

logger = logging.getLogger(__name__)

# Supported pairs
_PAIR_ALIASES = {
    "eurusd": "EUR_USD", "eur/usd": "EUR_USD", "eur usd": "EUR_USD", "euro dollar": "EUR_USD",
    "gbpusd": "GBP_USD", "gbp/usd": "GBP_USD", "gbp usd": "GBP_USD", "cable": "GBP_USD", "pound dollar": "GBP_USD",
    "usdjpy": "USD_JPY", "usd/jpy": "USD_JPY", "usd jpy": "USD_JPY", "dollar yen": "USD_JPY",
    "audusd": "AUD_USD", "aud/usd": "AUD_USD", "aussie": "AUD_USD",
    "usdcad": "USD_CAD", "usd/cad": "USD_CAD", "loonie": "USD_CAD",
    "usdchf": "USD_CHF", "usd/chf": "USD_CHF", "swissy": "USD_CHF",
    "nzdusd": "NZD_USD", "nzd/usd": "NZD_USD", "kiwi": "NZD_USD",
}

_BUY_KEYWORDS  = {"buy", "long", "purchase", "open buy", "go long", "bullish"}
_SELL_KEYWORDS = {"sell", "short", "open sell", "go short", "bearish"}
_CLOSE_KEYWORDS = {"close", "exit", "close trade", "close position", "exit trade"}
_SIGNAL_KEYWORDS = {"signal", "signals", "analyse", "analyze", "analysis", "what do you think", "trade idea"}
_NEWS_KEYWORDS = {"news", "headlines", "events", "calendar", "what's happening", "market update"}
_RISK_KEYWORDS = {"risk", "kelly", "position size", "lot size", "how much to trade"}
_BALANCE_KEYWORDS = {"balance", "account", "performance", "profit", "loss", "p&l", "stats"}


def _extract_pair(text: str) -> Optional[str]:
    lower = text.lower()
    for alias, pair in _PAIR_ALIASES.items():
        if alias in lower:
            return pair
    # Try pattern like "EUR/USD" or "EURUSD"
    match = re.search(r'\b([A-Z]{3})[/_]?([A-Z]{3})\b', text.upper())
    if match:
        return f"{match.group(1)}_{match.group(2)}"
    return None


def _extract_risk_pct(text: str) -> Optional[float]:
    match = re.search(r'(\d+(?:\.\d+)?)\s*%', text)
    if match:
        return float(match.group(1)) / 100
    match = re.search(r'(\d+(?:\.\d+)?)\s*percent', text.lower())
    if match:
        return float(match.group(1)) / 100
    return None


def _extract_amount(text: str) -> Optional[float]:
    match = re.search(r'\$?\s*(\d+(?:,\d{3})*(?:\.\d+)?)', text)
    if match:
        return float(match.group(1).replace(',', ''))
    return None


def parse_command(text: str, account_balance: float = 10000.0) -> Dict:
    """
    Parse a natural language trading command.
    Returns structured command dict with intent + parameters.
    """
    lower = text.lower().strip()
    words = set(lower.split())

    # Detect intent
    is_buy   = any(k in lower for k in _BUY_KEYWORDS)
    is_sell  = any(k in lower for k in _SELL_KEYWORDS)
    is_close = any(k in lower for k in _CLOSE_KEYWORDS)
    is_signal = any(k in lower for k in _SIGNAL_KEYWORDS)
    is_news  = any(k in lower for k in _NEWS_KEYWORDS)
    is_risk  = any(k in lower for k in _RISK_KEYWORDS)
    is_balance = any(k in lower for k in _BALANCE_KEYWORDS)

    pair     = _extract_pair(text)
    risk_pct = _extract_risk_pct(text)
    amount   = _extract_amount(text)

    # Trade intent
    if (is_buy or is_sell) and not is_close:
        direction  = "BUY" if is_buy else "SELL"
        risk_amount = (risk_pct or 0.01) * account_balance
        return {
            "intent":        "OPEN_TRADE",
            "direction":     direction,
            "pair":          pair or "EUR_USD",
            "risk_pct":      round(risk_pct or 0.01, 4),
            "risk_usd":      round(risk_amount, 2),
            "confidence":    0.85 if pair else 0.6,
            "response":      f"Opening {direction} on {(pair or 'EUR_USD').replace('_','/')} "
                             f"with {round((risk_pct or 0.01)*100, 1)}% risk (${round(risk_amount, 2)}). "
                             f"Confirm?",
            "requires_confirmation": True,
        }

    if is_close:
        return {
            "intent":    "CLOSE_TRADE",
            "pair":      pair,
            "confidence": 0.8,
            "response":  f"Closing {'your ' + pair.replace('_','/') + ' position' if pair else 'trade'}. Confirm?",
            "requires_confirmation": True,
        }

    if is_signal:
        return {
            "intent":    "GET_SIGNAL",
            "pair":      pair,
            "confidence": 0.9,
            "response":  f"Fetching {'live signal for ' + pair.replace('_','/') if pair else 'latest signals'}...",
            "requires_confirmation": False,
        }

    if is_news:
        return {
            "intent":    "GET_NEWS",
            "pair":      pair,
            "confidence": 0.9,
            "response":  "Fetching latest market news and economic events...",
            "requires_confirmation": False,
        }

    if is_risk:
        return {
            "intent":    "GET_RISK",
            "pair":      pair,
            "confidence": 0.85,
            "response":  "Calculating optimal position size using Kelly Criterion...",
            "requires_confirmation": False,
        }

    if is_balance:
        return {
            "intent":    "GET_PERFORMANCE",
            "confidence": 0.9,
            "response":  "Fetching your paper trading performance stats...",
            "requires_confirmation": False,
        }

    # Unknown â€” pass to Gemini
    return {
        "intent":    "CHAT",
        "confidence": 0.5,
        "response":  None,  # Let Gemini handle it
        "requires_confirmation": False,
    }