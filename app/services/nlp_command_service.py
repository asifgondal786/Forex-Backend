"""
NLP Command Service - parses natural language trade commands.
Uses AI Router (Claude + DeepSeek with fallback).
"""
import re
import json
import logging
from typing import Any, Optional

from app.ai.ai_router import route as ai_route

logger = logging.getLogger(__name__)

_PAIRS = [
    "EUR/USD", "GBP/USD", "USD/JPY", "USD/CHF", "AUD/USD",
    "NZD/USD", "USD/CAD", "EUR/GBP", "EUR/JPY", "GBP/JPY",
    "EUR/AUD", "EUR/CHF", "AUD/JPY", "CHF/JPY", "CAD/JPY",
    "NZD/JPY", "GBP/CHF", "GBP/AUD", "AUD/NZD", "XAU/USD",
]


def _extract_pair(text):
    upper = text.upper().replace(" ", "")
    for p in _PAIRS:
        clean = p.replace("/", "")
        if p in upper or clean in upper:
            return p
    return None


def _extract_risk_pct(text):
    m = re.search(r"(\d+(?:\.\d+)?)\s*%", text)
    return float(m.group(1)) if m else None


def _extract_price(text):
    m = re.search(r"(?:at|@|price)\s*(\d+\.?\d*)", text, re.IGNORECASE)
    return float(m.group(1)) if m else None


def _regex_parse(text, account_balance):
    lower = text.lower()
    pair = _extract_pair(text)
    risk = _extract_risk_pct(text)
    price = _extract_price(text)
    direction = None
    if any(w in lower for w in ("buy", "long", "bull")):
        direction = "buy"
    elif any(w in lower for w in ("sell", "short", "bear")):
        direction = "sell"
    action = "trade"
    if any(w in lower for w in ("close", "exit", "cancel")):
        action = "close"
    elif any(w in lower for w in ("status", "check", "show", "portfolio")):
        action = "query"
    elif any(w in lower for w in ("analyze", "analysis", "forecast", "predict")):
        action = "analysis"
    lot_size = None
    lm = re.search(r"(\d+\.?\d*)\s*lot", lower)
    if lm:
        lot_size = float(lm.group(1))
    return {
        "action": action,
        "pair": pair,
        "direction": direction,
        "risk_pct": risk,
        "price": price,
        "lot_size": lot_size,
        "raw_text": text,
        "source": "regex",
    }


async def _ai_validate(parsed):
    system_prompt = (
        "You are a forex trade command parser for Tajir app. "
        "Given a parsed command, validate and fill missing fields. "
        "Return ONLY valid JSON."
    )
    prompt = "Validate this forex command: " + json.dumps(parsed, default=str)
    try:
        result = await ai_route(
            prompt,
            task="nlp_command",
            system=system_prompt,
            max_tokens=300,
            temperature=0.1,
        )
        content = result["content"].strip()
        if content.startswith("``" + "`"):
            lines = content.split("\n")
            lines = [l for l in lines if not l.startswith("``" + "`")]
            content = "\n".join(lines).strip()
        ai_parsed = json.loads(content)
        ai_parsed["ai_provider"] = result.get("provider", "unknown")
        ai_parsed["ai_model"] = result.get("model", "unknown")
        ai_parsed["source"] = "ai_validated"
        return ai_parsed
    except Exception as exc:
        logger.warning("AI validation failed: %s", exc)
        parsed["ai_validation"] = "failed"
        return parsed


async def process_nlp_command(
    text,
    account_balance=10000.0,
    validate_with_ai=True,
):
    parsed = _regex_parse(text, account_balance)
    if validate_with_ai:
        parsed = await _ai_validate(parsed)
    return parsed
