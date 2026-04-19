# =============================================================
# D:\Tajir\Backend\app\routers\ai_proxy.py
#
# AI Proxy Router — DeepSeek powered
# Mounts at: /api/v1/ai/  (via _v1 in main.py)
#
# Endpoints:
#   POST /api/v1/ai/chat              — AI chat copilot
#   POST /api/v1/ai/analyze           — market analysis
#   POST /api/v1/ai/signal            — trade signal
#   POST /api/v1/ai/risk              — trade risk check
#   POST /api/v1/ai/news-impact       — news impact
#   POST /api/v1/ai/briefing          — autonomous briefing
#   GET  /api/v1/ai/health            — AI health check
# =============================================================

from __future__ import annotations

import logging
import os
from typing import Any

from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel, Field

from ..services.ai_analysis_service import (
    analyze_market,
    analyze_news_impact,
    analyze_trade_risk,
    autonomous_briefing,
    chat_with_ai,
    explain_prediction,
    generate_signal,
)
from ..ai.deepseek_client import health_check as deepseek_health

logger = logging.getLogger("app.routers.ai_proxy")

router = APIRouter(prefix="/ai", tags=["AI"])

_AI_ROUTES_ENABLED = os.getenv("AI_ROUTES_AVAILABLE", "false").lower() in {"true", "1", "yes"}


def _require_ai():
    """Dependency: blocks requests if AI routes are disabled."""
    if not _AI_ROUTES_ENABLED:
        raise HTTPException(
            status_code=503,
            detail="AI routes are currently disabled. Set AI_ROUTES_AVAILABLE=true to enable.",
        )


# ── Request / Response schemas ────────────────────────────────────────────────

class ChatRequest(BaseModel):
    messages: list[dict] = Field(..., description="Conversation history [{role, content}]")
    user_context: dict | None = None


class AnalyzeRequest(BaseModel):
    pair:          str  = Field(..., example="EUR/USD")
    timeframe:     str  = Field("1h", example="1h")
    include_news:  bool = True


class SignalRequest(BaseModel):
    pair:      str = Field(..., example="EUR/USD")
    timeframe: str = Field("1h", example="1h")


class RiskRequest(BaseModel):
    pair:            str   = Field(..., example="EUR/USD")
    direction:       str   = Field(..., example="BUY")
    entry_price:     float = Field(..., example=1.0850)
    stop_loss:       float = Field(..., example=1.0800)
    take_profit:     float = Field(..., example=1.0950)
    lot_size:        float = Field(..., example=0.1)
    account_balance: float = Field(..., example=1000.0)


class NewsImpactRequest(BaseModel):
    headlines: list[str] = Field(..., description="List of news headlines")
    pair:      str        = Field(..., example="EUR/USD")


class BriefingRequest(BaseModel):
    pairs:            list[str]  = Field(default=["EUR/USD", "GBP/USD", "USD/JPY"])
    stage:            str        = Field("monitoring", example="monitoring")
    user_instruction: str | None = None


class ExplainRequest(BaseModel):
    pair:       str = Field(..., example="EUR/USD")
    signal:     str = Field(..., example="BUY")
    confidence: int = Field(..., example=75)
    reasoning:  str = Field(..., example="RSI oversold with bullish divergence")
    audience:   str = Field("intermediate", example="beginner")


# ── Endpoints ─────────────────────────────────────────────────────────────────

@router.get("/health")
async def ai_health():
    """AI service health — always public, no auth needed."""
    ds_health = await deepseek_health()
    return {
        "status":              ds_health.get("status"),
        "ai_provider":         "deepseek",
        "model":               ds_health.get("model"),
        "routes_enabled":      _AI_ROUTES_ENABLED,
        "deepseek_reachable":  ds_health.get("status") == "ok",
    }


@router.post("/chat")
async def chat(req: ChatRequest, _: None = Depends(_require_ai)):
    """AI copilot chat — streaming-friendly conversational endpoint."""
    try:
        response = await chat_with_ai(req.messages, req.user_context)
        return {"response": response, "provider": "deepseek"}
    except Exception as exc:
        logger.exception("chat endpoint error")
        raise HTTPException(status_code=500, detail=str(exc))


@router.post("/analyze")
async def analyze(req: AnalyzeRequest, _: None = Depends(_require_ai)):
    """Full market analysis for a currency pair."""
    try:
        return await analyze_market(req.pair, req.timeframe, req.include_news)
    except Exception as exc:
        logger.exception("analyze endpoint error")
        raise HTTPException(status_code=500, detail=str(exc))


@router.post("/signal")
async def signal(req: SignalRequest, _: None = Depends(_require_ai)):
    """Fast BUY/SELL/HOLD signal generation."""
    try:
        return await generate_signal(req.pair, req.timeframe)
    except Exception as exc:
        logger.exception("signal endpoint error")
        raise HTTPException(status_code=500, detail=str(exc))


@router.post("/risk")
async def risk_check(req: RiskRequest, _: None = Depends(_require_ai)):
    """Pre-trade risk assessment."""
    try:
        return await analyze_trade_risk(
            pair=req.pair,
            direction=req.direction,
            entry_price=req.entry_price,
            stop_loss=req.stop_loss,
            take_profit=req.take_profit,
            lot_size=req.lot_size,
            account_balance=req.account_balance,
        )
    except Exception as exc:
        logger.exception("risk endpoint error")
        raise HTTPException(status_code=500, detail=str(exc))


@router.post("/news-impact")
async def news_impact(req: NewsImpactRequest, _: None = Depends(_require_ai)):
    """Analyze impact of news headlines on a pair."""
    try:
        return await analyze_news_impact(req.headlines, req.pair)
    except Exception as exc:
        raise HTTPException(status_code=500, detail=str(exc))


@router.post("/briefing")
async def briefing(req: BriefingRequest, _: None = Depends(_require_ai)):
    """Full autonomous agent stage briefing."""
    try:
        return await autonomous_briefing(req.pairs, req.stage, req.user_instruction)
    except Exception as exc:
        raise HTTPException(status_code=500, detail=str(exc))


@router.post("/explain")
async def explain(req: ExplainRequest, _: None = Depends(_require_ai)):
    """Explain a signal in plain English."""
    try:
        text = await explain_prediction(
            req.pair, req.signal, req.confidence, req.reasoning, req.audience
        )
        return {"explanation": text, "pair": req.pair}
    except Exception as exc:
        raise HTTPException(status_code=500, detail=str(exc))


# =============================================================
# D:\Tajir\Backend\app\market_routes.py  (ADDITIONS ONLY)
#
# Add these new endpoints to your existing market_routes.py.
# They wire all 8 forex APIs into the existing route structure.
# Do NOT replace the file — paste these into the existing router.
# =============================================================

"""
# ── PASTE THESE INTO app/market_routes.py ─────────────────────

from .services.forex_data_service import (
    get_rates,
    get_ohlc,
    get_forex_news,
    get_sentiment,
    get_indicators,
    get_market_snapshot,
    health_check as forex_health_check,
)

@router.get("/api/v1/market/rates")
async def market_rates(pairs: str | None = None):
    pair_list = pairs.split(",") if pairs else None
    return await get_rates(pair_list)


@router.get("/api/v1/market/snapshot")
async def market_snapshot(pairs: str | None = None):
    pair_list = pairs.split(",") if pairs else None
    return await get_market_snapshot(pair_list)


@router.get("/api/v1/market/ohlc")
async def market_ohlc(
    pair: str = "EUR/USD",
    interval: str = "1h",
    outputsize: int = 100,
):
    return await get_ohlc(pair, interval, outputsize)


@router.get("/api/v1/market/news")
async def market_news(pair: str | None = None, limit: int = 10):
    return await get_forex_news(pair, limit)


@router.get("/api/v1/market/sentiment")
async def market_sentiment(pair: str | None = None):
    return await get_sentiment(pair)


@router.get("/api/v1/market/indicators")
async def market_indicators(
    pair: str = "EUR/USD",
    indicator: str = "rsi",
    interval: str = "1h",
    period: int = 14,
):
    return await get_indicators(pair, indicator, interval, period)


@router.get("/api/v1/market/forex-health")
async def forex_health():
    return await forex_health_check()
"""