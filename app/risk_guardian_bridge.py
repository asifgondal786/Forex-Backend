"""
Tajir AI Risk Guardian — FastAPI Route + Middleware
Phase 17 — Updated: live spread from Pepperstone FIX price session.
"""
from fastapi import APIRouter, HTTPException, Depends, status
from pydantic import BaseModel
from typing import Optional
import logging

from app.risk.risk_models import (
    TradeRequest, AccountSnapshot, MarketSnapshot,
    RiskGuardianResult, RiskDecision,
)
from app.risk.risk_guardian import evaluate_trade
from app.services.pepperstone_fix_client import pepperstone

logger = logging.getLogger("risk_guardian")
risk_router = APIRouter(tags=["Risk Guardian"])


class GuardianCheckRequest(BaseModel):
    trade:   TradeRequest
    account: AccountSnapshot
    market:  MarketSnapshot


class GuardianCheckResponse(BaseModel):
    result:  RiskGuardianResult
    blocked: bool
    message: str


async def get_account_snapshot(user_id: str) -> AccountSnapshot:
    # TODO - replace with Supabase query
    return AccountSnapshot(
        balance=10_000.0, equity=9_800.0, current_drawdown_pct=2.0,
        daily_loss_pct=0.5, open_positions=2, win_rate_7d=55.0,
        consecutive_losses=1,
    )


async def get_market_snapshot(symbol: str) -> MarketSnapshot:
    """Pulls live spread from Pepperstone FIX price feed. Falls back to safe defaults."""
    price_data = pepperstone.get_price(symbol)
    spread_pips = 1.5   # safe default
    if price_data:
        try:
            bid = float(price_data.get("bid") or 0)
            ask = float(price_data.get("ask") or 0)
            if bid and ask:
                spread_pips = round((ask - bid) * 10_000, 1)
        except (ValueError, TypeError):
            pass
    return MarketSnapshot(
        symbol=symbol,
        current_spread_pips=spread_pips,
        atr_14=8.0,             # TODO: wire from technical_analysis_service
        is_news_window=False,   # TODO: wire from macro_event_service
        session="london",       # TODO: wire from session detector
        volatility_index=35.0,
    )


@risk_router.post("/risk/check", response_model=GuardianCheckResponse)
async def check_risk(body: GuardianCheckRequest):
    result = evaluate_trade(body.trade, body.account, body.market)
    return GuardianCheckResponse(result=result, blocked=not result.approved,
                                  message=result.explanation)


@risk_router.post("/risk/check-trade/{user_id}", response_model=GuardianCheckResponse)
async def check_trade_for_user(user_id: str, trade: TradeRequest):
    account = await get_account_snapshot(user_id)
    market  = await get_market_snapshot(trade.symbol)
    result  = evaluate_trade(trade, account, market)
    if result.decision == RiskDecision.BLOCK:
        logger.warning("BLOCKED trade user=%s symbol=%s score=%.1f",
                       user_id, trade.symbol, result.composite_score)
    return GuardianCheckResponse(result=result, blocked=not result.approved,
                                  message=result.explanation)


class AuditLogEntry(BaseModel):
    user_id: str; symbol: str; decision: RiskDecision
    composite_score: float; explanation: str; hard_limits_hit: list[str]


@risk_router.get("/risk/audit/{user_id}", response_model=list[AuditLogEntry])
async def get_audit_log(user_id: str, limit: int = 20):
    return []  # TODO: Supabase query


async def guard_trade(user_id: str, trade: TradeRequest) -> RiskGuardianResult:
    account = await get_account_snapshot(user_id)
    market  = await get_market_snapshot(trade.symbol)
    return evaluate_trade(trade, account, market)
