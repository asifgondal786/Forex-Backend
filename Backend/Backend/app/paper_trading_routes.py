"""
app/paper_trading_routes.py
Phase 5 - Paper Trading Endpoints
"""
import logging
from typing import Optional
from fastapi import APIRouter, HTTPException, Query, Request
from pydantic import BaseModel
from app.services.paper_trading_service import (
    open_paper_trade,
    close_paper_trade,
    get_open_trades,
    get_trade_history,
    get_performance_stats,
)

logger = logging.getLogger(__name__)
router = APIRouter(prefix="/api/v1/paper", tags=["Paper Trading"])


class OpenTradeRequest(BaseModel):
    user_id:     str
    pair:        str
    direction:   str
    entry_price: float
    stop_loss:   float
    take_profit: float
    lot_size:    float = 1000.0
    signal_id:   Optional[str] = None
    reasoning:   Optional[str] = None


class CloseTradeRequest(BaseModel):
    trade_id:     str
    close_price:  float
    close_reason: str = "manual"


@router.post("/open", summary="Open a virtual paper trade")
async def open_trade(req: OpenTradeRequest) -> dict:
    try:
        result = await open_paper_trade(
            user_id=req.user_id,
            pair=req.pair,
            direction=req.direction,
            entry_price=req.entry_price,
            stop_loss=req.stop_loss,
            take_profit=req.take_profit,
            lot_size=req.lot_size,
            signal_id=req.signal_id,
            reasoning=req.reasoning,
        )
        return result
    except Exception as e:
        logger.exception("open_trade error")
        raise HTTPException(status_code=500, detail=str(e))


@router.post("/close", summary="Close an open paper trade")
async def close_trade(req: CloseTradeRequest) -> dict:
    try:
        result = await close_paper_trade(
            trade_id=req.trade_id,
            close_price=req.close_price,
            close_reason=req.close_reason,
        )
        if not result.get("success"):
            raise HTTPException(status_code=404, detail=result.get("error", "Trade not found"))
        return result
    except HTTPException:
        raise
    except Exception as e:
        logger.exception("close_trade error")
        raise HTTPException(status_code=500, detail=str(e))


@router.get("/trades/open", summary="Get open paper trades")
async def get_open(user_id: str = Query(...)) -> dict:
    try:
        trades = await get_open_trades(user_id)
        return {"trades": trades, "count": len(trades)}
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


@router.get("/trades/history", summary="Get closed trade history")
async def get_history(
    user_id: str = Query(...),
    limit: int = Query(default=50, ge=1, le=200),
) -> dict:
    try:
        trades = await get_trade_history(user_id, limit=limit)
        return {"trades": trades, "count": len(trades)}
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


@router.get("/performance", summary="Get trading performance stats")
async def get_performance(user_id: str = Query(...)) -> dict:
    try:
        stats = await get_performance_stats(user_id)
        return stats
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


@router.get("/health", summary="Paper trading health check")
async def paper_health() -> dict:
    import os
    return {
        "status":      "ok",
        "phase":       5,
        "supabase_ok": bool(os.getenv("SUPABASE_URL")),
    }