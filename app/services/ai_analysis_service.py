# =============================================================
# D:\Tajir\Backend\app\services\ai_analysis_service.py
#
# AI Analysis Service — powered by DeepSeek
# Replaces the old Gemini-based implementation.
#
# Provides:
#   • analyze_market()       — full market intelligence report
#   • generate_signal()      — BUY/SELL/HOLD with confidence
#   • analyze_trade_risk()   — risk assessment before execution
#   • explain_prediction()   — plain-English explanation
#   • chat_with_ai()         — general trading AI assistant
#   • analyze_news_impact()  — news → price impact scoring
#   • autonomous_briefing()  — full autonomous agent stage report
# =============================================================

from __future__ import annotations

import logging
from typing import Any

from .forex_data_service import (
    get_indicators,
    get_market_snapshot,
    get_forex_news,
    get_sentiment,
)
from ..ai.deepseek_client import chat_completion_json, chat_completion

logger = logging.getLogger("app.services.ai_analysis_service")

# ── System prompts ────────────────────────────────────────────────────────────

_MARKET_ANALYST_SYSTEM = """You are an expert forex market analyst with 20+ years experience.
You provide precise, data-driven analysis. Always respond in valid JSON.
Be concise, actionable, and base everything on the data provided.
Never fabricate prices — use only what is given."""

_RISK_MANAGER_SYSTEM = """You are a professional forex risk manager.
Your job is to assess trade risk, suggest position sizing, and protect capital.
Always respond in valid JSON. Be conservative and prioritize capital preservation."""

_TRADING_ASSISTANT_SYSTEM = """You are Tajir AI, an expert forex trading assistant.
You help traders understand markets, manage risk, and execute better trades.
Be helpful, clear, and educational. Respond in plain English unless JSON is requested."""


# ── Core analysis functions ───────────────────────────────────────────────────

async def analyze_market(
    pair: str,
    timeframe: str = "1h",
    include_news: bool = True,
) -> dict[str, Any]:
    """
    Full market intelligence report for a currency pair.
    Combines live rates, indicators, news and sentiment into DeepSeek analysis.
    """
    # Gather data concurrently
    import asyncio
    snapshot_task    = get_market_snapshot([pair])
    indicators_task  = get_indicators(pair, "rsi", timeframe, 14)
    macd_task        = get_indicators(pair, "macd", timeframe, 12)
    news_task        = get_forex_news(pair, 5) if include_news else None
    sentiment_task   = get_sentiment(pair)

    tasks = [snapshot_task, indicators_task, macd_task, sentiment_task]
    if news_task:
        tasks.append(news_task)

    results = await asyncio.gather(*tasks, return_exceptions=True)

    snapshot   = results[0] if not isinstance(results[0], Exception) else {}
    rsi_data   = results[1] if not isinstance(results[1], Exception) else {}
    macd_data  = results[2] if not isinstance(results[2], Exception) else {}
    sentiment  = results[3] if not isinstance(results[3], Exception) else {}
    news       = results[4] if (len(results) > 4 and not isinstance(results[4], Exception)) else {}

    current_price = (snapshot.get("rates") or {}).get(pair, 0)
    rsi_value     = (rsi_data.get("value") or {}).get("rsi")
    macd_hist     = (macd_data.get("value") or {}).get("macd_hist")
    news_headlines = [a.get("headline", "") for a in (news.get("articles") or [])[:3]]

    prompt = f"""Analyze {pair} on {timeframe} timeframe.

Current price: {current_price}
RSI ({timeframe}): {rsi_value}
MACD histogram: {macd_hist}
Market sentiment: {sentiment.get('sentiment', 'neutral')} (score: {sentiment.get('score', 0)})
Recent headlines: {news_headlines}

Provide analysis as JSON with these exact keys:
{{
  "pair": "{pair}",
  "timeframe": "{timeframe}",
  "current_price": <number>,
  "trend": "bullish|bearish|sideways",
  "trend_strength": "strong|moderate|weak",
  "signal": "BUY|SELL|HOLD",
  "confidence": <0-100>,
  "entry_zone": {{"min": <number>, "max": <number>}},
  "stop_loss": <number>,
  "take_profit_1": <number>,
  "take_profit_2": <number>,
  "risk_reward": <number>,
  "key_levels": {{"support": [<number>], "resistance": [<number>]}},
  "reasoning": "<2-3 sentence analysis>",
  "risk_warning": "<one sentence>",
  "indicators": {{"rsi": {rsi_value}, "macd_hist": {macd_hist}}},
  "news_impact": "positive|negative|neutral"
}}"""

    try:
        result = await chat_completion_json(
            [{"role": "user", "content": prompt}],
            system_prompt=_MARKET_ANALYST_SYSTEM,
            temperature=0.1,
        )
        result["source"]    = "deepseek"
        result["data_from"] = snapshot.get("source", "unknown")
        return result
    except Exception as exc:
        logger.error("analyze_market failed for %s: %s", pair, exc)
        return {
            "pair":        pair,
            "signal":      "HOLD",
            "confidence":  0,
            "error":       str(exc),
            "reasoning":   "Analysis unavailable — AI service error.",
        }


async def generate_signal(
    pair: str,
    timeframe: str = "1h",
) -> dict[str, Any]:
    """
    Fast signal generation: BUY / SELL / HOLD with confidence score.
    Optimised for low latency — fewer data sources than full analysis.
    """
    rates = await get_market_snapshot([pair])
    rsi   = await get_indicators(pair, "rsi", timeframe, 14)

    price     = (rates.get("rates") or {}).get(pair, 0)
    rsi_val   = (rsi.get("value") or {}).get("rsi")

    prompt = f"""Generate a forex trading signal for {pair}.
Price: {price}, RSI: {rsi_val}, Timeframe: {timeframe}

Respond ONLY with JSON:
{{
  "pair": "{pair}",
  "signal": "BUY|SELL|HOLD",
  "confidence": <0-100>,
  "entry": <price>,
  "stop_loss": <price>,
  "take_profit": <price>,
  "reasoning": "<one sentence>"
}}"""

    try:
        return await chat_completion_json(
            [{"role": "user", "content": prompt}],
            system_prompt=_MARKET_ANALYST_SYSTEM,
            temperature=0.1,
        )
    except Exception as exc:
        logger.error("generate_signal failed: %s", exc)
        return {"pair": pair, "signal": "HOLD", "confidence": 0, "error": str(exc)}


async def analyze_trade_risk(
    pair: str,
    direction: str,
    entry_price: float,
    stop_loss: float,
    take_profit: float,
    lot_size: float,
    account_balance: float,
) -> dict[str, Any]:
    """
    Risk assessment before trade execution.
    Returns risk percentage, R:R ratio, and recommendation.
    """
    risk_pips   = abs(entry_price - stop_loss)
    reward_pips = abs(take_profit - entry_price)
    rr_ratio    = round(reward_pips / risk_pips, 2) if risk_pips else 0
    risk_amount = lot_size * risk_pips * 10000  # approximate pip value

    prompt = f"""Assess this forex trade risk:
Pair: {pair}, Direction: {direction}
Entry: {entry_price}, Stop Loss: {stop_loss}, Take Profit: {take_profit}
Lot Size: {lot_size}, Account Balance: ${account_balance}
Risk in pips: {risk_pips:.4f}, R:R ratio: {rr_ratio}
Estimated risk amount: ${risk_amount:.2f}

Respond ONLY with JSON:
{{
  "approved": true|false,
  "risk_percentage": <0-100>,
  "risk_rating": "low|medium|high|extreme",
  "rr_ratio": {rr_ratio},
  "max_recommended_lot": <number>,
  "recommendation": "PROCEED|REDUCE_SIZE|WIDEN_STOP|ABORT",
  "warnings": ["<warning1>", "<warning2>"],
  "reasoning": "<2 sentence explanation>"
}}"""

    try:
        return await chat_completion_json(
            [{"role": "user", "content": prompt}],
            system_prompt=_RISK_MANAGER_SYSTEM,
            temperature=0.05,
        )
    except Exception as exc:
        logger.error("analyze_trade_risk failed: %s", exc)
        return {
            "approved":    False,
            "risk_rating": "unknown",
            "recommendation": "ABORT",
            "error": str(exc),
        }


async def explain_prediction(
    pair: str,
    signal: str,
    confidence: int,
    reasoning: str,
    audience: str = "intermediate",
) -> str:
    """
    Converts AI signal data into plain-English explanation for the user.
    audience: "beginner" | "intermediate" | "expert"
    """
    prompt = f"""Explain this forex signal to a {audience} trader:
Pair: {pair}, Signal: {signal}, Confidence: {confidence}%
Technical reasoning: {reasoning}

Write 2-3 clear sentences. No jargon for beginners. Be direct and helpful."""

    try:
        return await chat_completion(
            [{"role": "user", "content": prompt}],
            system_prompt=_TRADING_ASSISTANT_SYSTEM,
            temperature=0.4,
        )
    except Exception as exc:
        return f"Analysis for {pair}: {signal} signal with {confidence}% confidence. {reasoning}"


async def chat_with_ai(
    messages: list[dict],
    user_context: dict | None = None,
) -> str:
    """
    General trading AI chat — powers the AI copilot chat interface.
    Maintains conversation history via messages list.
    """
    context_note = ""
    if user_context:
        context_note = f"\nUser context: {user_context}"

    system = _TRADING_ASSISTANT_SYSTEM + context_note

    try:
        return await chat_completion(
            messages,
            system_prompt=system,
            temperature=0.5,
        )
    except Exception as exc:
        logger.error("chat_with_ai failed: %s", exc)
        return "I'm having trouble connecting to the AI service. Please try again."


async def analyze_news_impact(
    headlines: list[str],
    pair: str,
) -> dict[str, Any]:
    """
    Scores the impact of news headlines on a currency pair.
    """
    headlines_str = "\n".join(f"- {h}" for h in headlines[:10])

    prompt = f"""Analyze how these news headlines affect {pair}:
{headlines_str}

Respond ONLY with JSON:
{{
  "pair": "{pair}",
  "overall_impact": "very_bullish|bullish|neutral|bearish|very_bearish",
  "impact_score": <-5 to 5>,
  "key_drivers": ["<driver1>", "<driver2>"],
  "risk_events": ["<event1>"],
  "trading_bias": "BUY|SELL|AVOID",
  "confidence": <0-100>,
  "summary": "<2 sentence summary>"
}}"""

    try:
        return await chat_completion_json(
            [{"role": "user", "content": prompt}],
            system_prompt=_MARKET_ANALYST_SYSTEM,
            temperature=0.1,
        )
    except Exception as exc:
        return {"pair": pair, "overall_impact": "neutral", "error": str(exc)}


async def autonomous_briefing(
    pairs: list[str],
    stage: str,
    user_instruction: str | None = None,
) -> dict[str, Any]:
    """
    Full autonomous agent stage briefing.
    Called by the autonomous service at each pipeline stage.
    """
    import asyncio

    # Gather snapshots for all pairs
    snapshots = await asyncio.gather(
        *[get_market_snapshot([p]) for p in pairs],
        return_exceptions=True,
    )

    rates_summary = {}
    for i, snap in enumerate(snapshots):
        if isinstance(snap, dict):
            rates_summary[pairs[i]] = (snap.get("rates") or {}).get(pairs[i], "N/A")

    instruction_note = f"\nUser directive: {user_instruction}" if user_instruction else ""

    prompt = f"""Autonomous stage briefing — Stage: {stage}
Current rates: {rates_summary}{instruction_note}

Provide a comprehensive JSON briefing:
{{
  "stage": "{stage}",
  "market_summary": "<2 sentence overview>",
  "opportunities": [
    {{
      "pair": "<pair>",
      "action": "BUY|SELL|WATCH",
      "confidence": <0-100>,
      "reason": "<one sentence>"
    }}
  ],
  "risks": ["<risk1>", "<risk2>"],
  "recommended_actions": ["<action1>", "<action2>"],
  "overall_market_bias": "risk_on|risk_off|neutral",
  "next_stage_recommendation": "<monitoring|analysis|execution|standby>"
}}"""

    try:
        result = await chat_completion_json(
            [{"role": "user", "content": prompt}],
            system_prompt=_MARKET_ANALYST_SYSTEM,
            temperature=0.15,
        )
        result["rates"] = rates_summary
        return result
    except Exception as exc:
        logger.error("autonomous_briefing failed: %s", exc)
        return {
            "stage":    stage,
            "error":    str(exc),
            "rates":    rates_summary,
            "market_summary": "Briefing unavailable.",
        }