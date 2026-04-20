"""
app/risk_routes.py
Phase 6 - Risk Guardian Endpoints
"""
import logging
from fastapi import APIRouter, Query
from pydantic import BaseModel
from typing import List, Optional
from app.services.risk_guardian_service import (
    calculate_kelly,
    calculate_drawdown_controls,
    calculate_correlation_risk,
    run_stress_test,
)
import numpy as np

logger = logging.getLogger(__name__)
router = APIRouter(prefix="/api/v1/risk", tags=["Risk Guardian"])


class RiskSimRequest(BaseModel):
    win_rate:         float = 0.55
    avg_win:          float = 50.0
    avg_loss:         float = 30.0
    num_trades:       int   = 100
    starting_balance: float = 10000.0
    simulations:      int   = 1000


class KellyRequest(BaseModel):
    win_rate:        float = 0.55
    avg_win:         float = 50.0
    avg_loss:        float = 30.0
    account_balance: float = 10000.0
    kelly_fraction:  float = 0.25


class DrawdownRequest(BaseModel):
    account_balance:       float = 10000.0
    daily_loss_limit_pct:  float = 0.03
    weekly_loss_limit_pct: float = 0.06
    max_open_trades:       int   = 3
    risk_per_trade_pct:    float = 0.01


class PositionInput(BaseModel):
    pair:      str
    direction: str = "BUY"


class CorrelationRequest(BaseModel):
    positions: List[PositionInput]


@router.post("/simulate", summary="Monte Carlo risk simulation")
async def simulate_risk(req: RiskSimRequest) -> dict:
    try:
        rng = np.random.default_rng()
        results = []
        final_balances = []
        max_drawdowns  = []

        for _ in range(req.simulations):
            balance = req.starting_balance
            peak    = balance
            max_dd  = 0.0
            equity_curve = [balance]
            outcomes = rng.random(req.num_trades)
            for outcome in outcomes:
                balance += req.avg_win if outcome < req.win_rate else -req.avg_loss
                balance  = max(balance, 0)
                if balance > peak:
                    peak = balance
                dd = (peak - balance) / peak if peak > 0 else 0
                if dd > max_dd:
                    max_dd = dd
                equity_curve.append(round(balance, 2))
            results.append(equity_curve)
            final_balances.append(balance)
            max_drawdowns.append(max_dd)

        fb  = np.array(final_balances)
        mdd = np.array(max_drawdowns)
        indices = np.linspace(0, req.simulations - 1, min(50, req.simulations), dtype=int)
        sampled_curves = [results[i] for i in indices]

        return {
            "simulations":     req.simulations,
            "num_trades":      req.num_trades,
            "starting_balance": req.starting_balance,
            "sampled_curves":  sampled_curves,
            "statistics": {
                "median_final":        round(float(np.median(fb)), 2),
                "mean_final":          round(float(np.mean(fb)), 2),
                "p10_final":           round(float(np.percentile(fb, 10)), 2),
                "p90_final":           round(float(np.percentile(fb, 90)), 2),
                "prob_profit":         round(float(np.mean(fb > req.starting_balance)), 4),
                "prob_ruin":           round(float(np.mean(fb <= 0)), 4),
                "median_max_drawdown": round(float(np.median(mdd)), 4),
                "p90_max_drawdown":    round(float(np.percentile(mdd, 90)), 4),
            },
        }
    except Exception as e:
        logger.exception("Monte Carlo error")
        return {"error": str(e)}


@router.post("/kelly", summary="Kelly Criterion position sizing")
async def kelly_criterion(req: KellyRequest) -> dict:
    try:
        return calculate_kelly(
            win_rate=req.win_rate,
            avg_win=req.avg_win,
            avg_loss=req.avg_loss,
            account_balance=req.account_balance,
            kelly_fraction=req.kelly_fraction,
        )
    except Exception as e:
        logger.exception("Kelly error")
        return {"error": str(e)}


@router.post("/drawdown", summary="Drawdown controls calculator")
async def drawdown_controls(req: DrawdownRequest) -> dict:
    try:
        return calculate_drawdown_controls(
            account_balance=req.account_balance,
            daily_loss_limit_pct=req.daily_loss_limit_pct,
            weekly_loss_limit_pct=req.weekly_loss_limit_pct,
            max_open_trades=req.max_open_trades,
            risk_per_trade_pct=req.risk_per_trade_pct,
        )
    except Exception as e:
        logger.exception("Drawdown error")
        return {"error": str(e)}


@router.post("/correlation", summary="Correlation risk dashboard")
async def correlation_risk(req: CorrelationRequest) -> dict:
    try:
        positions = [{"pair": p.pair, "direction": p.direction} for p in req.positions]
        return calculate_correlation_risk(positions)
    except Exception as e:
        logger.exception("Correlation error")
        return {"error": str(e)}


@router.post("/stress-test", summary="Advanced Monte Carlo stress test")
async def stress_test(req: RiskSimRequest) -> dict:
    try:
        return run_stress_test(
            win_rate=req.win_rate,
            avg_win=req.avg_win,
            avg_loss=req.avg_loss,
            starting_balance=req.starting_balance,
            num_trades=req.num_trades,
            simulations=min(req.simulations, 500),
        )
    except Exception as e:
        logger.exception("Stress test error")
        return {"error": str(e)}


@router.get("/health", summary="Risk Guardian health")
async def risk_health() -> dict:
    return {"status": "ok", "phase": 6, "numpy_available": True}