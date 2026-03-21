"""
app/risk_routes.py
Monte Carlo Risk Simulator - POST /api/v1/risk/simulate
"""
import logging
import numpy as np
from fastapi import APIRouter
from pydantic import BaseModel

logger = logging.getLogger(__name__)
router = APIRouter(prefix="/api/v1/risk", tags=["Risk"])

class RiskSimRequest(BaseModel):
    win_rate: float = 0.55
    avg_win: float = 50.0
    avg_loss: float = 30.0
    num_trades: int = 100
    starting_balance: float = 10000.0
    simulations: int = 1000

@router.post("/simulate", summary="Monte Carlo risk simulation")
async def simulate_risk(req: RiskSimRequest) -> dict:
    try:
        rng = np.random.default_rng()
        results = []
        final_balances = []
        max_drawdowns = []

        for _ in range(req.simulations):
            balance = req.starting_balance
            peak = balance
            max_dd = 0.0
            equity_curve = [balance]

            outcomes = rng.random(req.num_trades)
            for outcome in outcomes:
                if outcome < req.win_rate:
                    balance += req.avg_win
                else:
                    balance -= req.avg_loss
                balance = max(balance, 0)
                if balance > peak:
                    peak = balance
                dd = (peak - balance) / peak if peak > 0 else 0
                if dd > max_dd:
                    max_dd = dd
                equity_curve.append(round(balance, 2))

            results.append(equity_curve)
            final_balances.append(balance)
            max_drawdowns.append(max_dd)

        final_balances = np.array(final_balances)
        max_drawdowns = np.array(max_drawdowns)

        # Sample 50 curves for frontend chart
        indices = np.linspace(0, req.simulations - 1, min(50, req.simulations), dtype=int)
        sampled_curves = [results[i] for i in indices]

        return {
            "simulations": req.simulations,
            "num_trades": req.num_trades,
            "starting_balance": req.starting_balance,
            "sampled_curves": sampled_curves,
            "statistics": {
                "median_final": round(float(np.median(final_balances)), 2),
                "mean_final": round(float(np.mean(final_balances)), 2),
                "p10_final": round(float(np.percentile(final_balances, 10)), 2),
                "p90_final": round(float(np.percentile(final_balances, 90)), 2),
                "prob_profit": round(float(np.mean(final_balances > req.starting_balance)), 4),
                "prob_ruin": round(float(np.mean(final_balances <= 0)), 4),
                "median_max_drawdown": round(float(np.median(max_drawdowns)), 4),
                "p90_max_drawdown": round(float(np.percentile(max_drawdowns, 90)), 4),
            }
        }
    except Exception as e:
        logger.exception("Monte Carlo simulation error")
        return {"error": str(e)}

@router.get("/health", summary="Risk simulator health")
async def risk_health() -> dict:
    return {"status": "ok", "numpy_available": True}
