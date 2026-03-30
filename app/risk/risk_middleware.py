"""
Tajir AI Risk Guardian — FastAPI Route + Middleware
Phase 17

Drop this file into your existing FastAPI app.
Add `router` to your main app:  app.include_router(risk_router, prefix="/api/v1")

The middleware function `guard_trade` is what you inject into your
existing trade execution route — see the example at the bottom.
"""

from fastapi import APIRouter, HTTPException, Depends, status
from pydantic import BaseModel
from typing import Optional
import logging

from risk_models import (
    TradeRequest, AccountSnapshot, MarketSnapshot,
    RiskGuardianResult, RiskDecision,
)
from risk_guardian import evaluate_trade

logger = logging.getLogger("risk_guardian")

risk_router = APIRouter(tags=["Risk Guardian"])


# ─── Request/Response wrappers ────────────────────────────────────────────────

class GuardianCheckRequest(BaseModel):
    trade:   TradeRequest
    account: AccountSnapshot
    market:  MarketSnapshot


class GuardianCheckResponse(BaseModel):
    result:   RiskGuardianResult
    blocked:  bool
    message:  str


# ─── Dependency: fetch account snapshot from DB ───────────────────────────────
# Replace this stub with your actual Supabase query

async def get_account_snapshot(user_id: str) -> AccountSnapshot:
    """
    STUB — replace with Supabase query:
        data = supabase.table("account_snapshots")
               .select("*")
               .eq("user_id", user_id)
               .single()
               .execute()
        return AccountSnapshot(**data.data)
    """
    return AccountSnapshot(
        balance=10_000.0,
        equity=9_800.0,
        current_drawdown_pct=2.0,
        daily_loss_pct=0.5,
        open_positions=2,
        win_rate_7d=55.0,
        consecutive_losses=1,
    )


async def get_market_snapshot(symbol: str) -> MarketSnapshot:
    """
    STUB — replace with your broker/price-feed integration:
        - ATR from MT5 or broker REST API
        - Spread from live tick
        - is_news_window from your economic calendar service
    """
    return MarketSnapshot(
        symbol=symbol,
        current_spread_pips=1.5,
        atr_14=8.0,
        is_news_window=False,
        session="london",
        volatility_index=35.0,
    )


# ─── Routes ───────────────────────────────────────────────────────────────────

@risk_router.post("/risk/check", response_model=GuardianCheckResponse)
async def check_risk(body: GuardianCheckRequest):
    """
    Direct risk check endpoint.
    Accepts full trade + account + market data in the request body.
    Used by the frontend Risk Guardian card for live preview before submission.
    """
    result = evaluate_trade(body.trade, body.account, body.market)
    blocked = not result.approved

    return GuardianCheckResponse(
        result=result,
        blocked=blocked,
        message=result.explanation,
    )


@risk_router.post("/risk/check-trade/{user_id}", response_model=GuardianCheckResponse)
async def check_trade_for_user(
    user_id: str,
    trade: TradeRequest,
):
    """
    Lightweight endpoint — pass trade only.
    Account + market data fetched server-side.
    Used by the autonomous engine before sending to broker.
    """
    account = await get_account_snapshot(user_id)
    market  = await get_market_snapshot(trade.symbol)
    result  = evaluate_trade(trade, account, market)

    if result.decision == RiskDecision.BLOCK:
        logger.warning(
            "BLOCKED trade for user=%s symbol=%s score=%.1f limits=%s",
            user_id, trade.symbol, result.composite_score, result.hard_limits_hit,
        )

    return GuardianCheckResponse(
        result=result,
        blocked=not result.approved,
        message=result.explanation,
    )


# ─── Audit Log Route ─────────────────────────────────────────────────────────

class AuditLogEntry(BaseModel):
    user_id:         str
    symbol:          str
    decision:        RiskDecision
    composite_score: float
    explanation:     str
    hard_limits_hit: list[str]


@risk_router.get("/risk/audit/{user_id}", response_model=list[AuditLogEntry])
async def get_audit_log(user_id: str, limit: int = 20):
    """
    Returns the last N risk evaluations for a user.
    STUB — replace with Supabase query:
        data = supabase.table("risk_audit_log")
               .select("*")
               .eq("user_id", user_id)
               .order("created_at", desc=True)
               .limit(limit)
               .execute()
    """
    return []   # Replace with real query


# ─── Middleware helper: inject into your trade execution route ─────────────────

async def guard_trade(
    user_id: str,
    trade: TradeRequest,
) -> RiskGuardianResult:
    """
    Call this at the TOP of your existing trade execution function.

    Example usage in your existing route:
    ──────────────────────────────────────────────────────────────────
    @router.post("/trade/execute")
    async def execute_trade(user_id: str, trade: TradeRequest):

        risk = await guard_trade(user_id, trade)

        if not risk.approved:
            raise HTTPException(
                status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
                detail={
                    "blocked": True,
                    "score": risk.composite_score,
                    "decision": risk.decision,
                    "explanation": risk.explanation,
                    "flags": risk.hard_limits_hit or (
                        risk.position_score.flags +
                        risk.account_score.flags +
                        risk.market_score.flags
                    ),
                    "suggested_lot_size": risk.suggested_lot_size,
                }
            )

        # ... rest of your existing trade execution logic
    ──────────────────────────────────────────────────────────────────
    """
    account = await get_account_snapshot(user_id)
    market  = await get_market_snapshot(trade.symbol)
    result  = evaluate_trade(trade, account, market)

    # ── Audit log write (replace stub with real Supabase insert) ──
    # await supabase.table("risk_audit_log").insert({
    #     "user_id":         user_id,
    #     "symbol":          trade.symbol,
    #     "direction":       trade.direction,
    #     "lot_size":        trade.lot_size,
    #     "composite_score": result.composite_score,
    #     "decision":        result.decision,
    #     "explanation":     result.explanation,
    #     "flags":           result.position_score.flags + result.account_score.flags + result.market_score.flags,
    #     "hard_limits_hit": result.hard_limits_hit,
    #     "source":          trade.source,
    # }).execute()

    return result