"""
app/services/risk_guardian_service.py
Phase 6 - Risk Guardian
Kelly Criterion, drawdown controls, correlation risk dashboard.
"""
from __future__ import annotations

import logging
import math
from typing import Dict, List, Optional
import httpx
import os

logger = logging.getLogger(__name__)
TWELVE_DATA_KEY = os.getenv("TWELVE_DATA_API_KEY", "")
TWELVE_DATA_URL = "https://api.twelvedata.com"


# ── Kelly Criterion ───────────────────────────────────────────────────────────

def calculate_kelly(
    win_rate: float,
    avg_win: float,
    avg_loss: float,
    account_balance: float,
    kelly_fraction: float = 0.25,  # quarter-Kelly for safety
) -> Dict:
    """
    Full Kelly + fractional Kelly position sizing.
    Returns recommended lot size and risk per trade.
    """
    if avg_loss <= 0 or win_rate <= 0 or win_rate >= 1:
        return {"error": "Invalid inputs"}

    rr_ratio  = avg_win / avg_loss
    loss_rate = 1 - win_rate

    # Full Kelly fraction
    full_kelly = win_rate - (loss_rate / rr_ratio)
    full_kelly = max(full_kelly, 0)

    # Apply fractional Kelly (quarter-Kelly default)
    safe_kelly = full_kelly * kelly_fraction

    # Dollar risk per trade
    risk_per_trade = account_balance * safe_kelly
    risk_per_trade = min(risk_per_trade, account_balance * 0.05)  # hard cap 5%

    # Pip-based lot size (standard lot = 100k units, $10/pip)
    pip_value_per_lot = 10.0
    recommended_lots  = risk_per_trade / (avg_loss * pip_value_per_lot)
    recommended_lots  = max(round(recommended_lots, 2), 0.01)

    return {
        "full_kelly_pct":     round(full_kelly * 100, 2),
        "safe_kelly_pct":     round(safe_kelly * 100, 2),
        "kelly_fraction_used": kelly_fraction,
        "risk_per_trade_usd": round(risk_per_trade, 2),
        "risk_pct_of_account": round(safe_kelly * 100, 2),
        "recommended_lots":   recommended_lots,
        "rr_ratio":           round(rr_ratio, 2),
        "win_rate_pct":       round(win_rate * 100, 1),
        "interpretation": (
            "AGGRESSIVE — consider reducing Kelly fraction"
            if full_kelly > 0.3
            else "MODERATE — healthy position sizing"
            if full_kelly > 0.1
            else "CONSERVATIVE — edge may be weak"
        ),
    }


# ── Drawdown Controls ─────────────────────────────────────────────────────────

def calculate_drawdown_controls(
    account_balance: float,
    daily_loss_limit_pct: float = 0.03,   # 3% daily
    weekly_loss_limit_pct: float = 0.06,  # 6% weekly
    max_open_trades: int = 3,
    risk_per_trade_pct: float = 0.01,     # 1% per trade
) -> Dict:
    """
    Compute drawdown thresholds and trading pause rules.
    """
    daily_limit_usd   = account_balance * daily_loss_limit_pct
    weekly_limit_usd  = account_balance * weekly_loss_limit_pct
    risk_per_trade    = account_balance * risk_per_trade_pct
    max_portfolio_risk = risk_per_trade * max_open_trades

    # Ruin threshold — stop trading if balance drops this much
    ruin_threshold_pct = 0.20
    ruin_threshold_usd = account_balance * ruin_threshold_pct

    return {
        "account_balance":      account_balance,
        "daily_limit_usd":      round(daily_limit_usd, 2),
        "daily_limit_pct":      round(daily_loss_limit_pct * 100, 1),
        "weekly_limit_usd":     round(weekly_limit_usd, 2),
        "weekly_limit_pct":     round(weekly_loss_limit_pct * 100, 1),
        "risk_per_trade_usd":   round(risk_per_trade, 2),
        "risk_per_trade_pct":   round(risk_per_trade_pct * 100, 1),
        "max_open_trades":      max_open_trades,
        "max_portfolio_risk":   round(max_portfolio_risk, 2),
        "ruin_threshold_usd":   round(ruin_threshold_usd, 2),
        "ruin_threshold_pct":   round(ruin_threshold_pct * 100, 1),
        "rules": [
            f"Stop trading today if loss exceeds ${round(daily_limit_usd, 0):.0f}",
            f"Stop trading this week if loss exceeds ${round(weekly_limit_usd, 0):.0f}",
            f"Max {max_open_trades} open trades simultaneously",
            f"Risk max ${round(risk_per_trade, 0):.0f} ({risk_per_trade_pct*100:.0f}%) per trade",
            f"Seek help if account drops below ${round(account_balance - ruin_threshold_usd, 0):.0f}",
        ],
    }


# ── Correlation Risk ──────────────────────────────────────────────────────────

# Known forex correlations (static lookup — updated periodically)
_CORRELATIONS = {
    ("EUR_USD", "GBP_USD"): 0.87,
    ("EUR_USD", "AUD_USD"): 0.72,
    ("EUR_USD", "NZD_USD"): 0.68,
    ("EUR_USD", "USD_CHF"): -0.92,
    ("EUR_USD", "USD_JPY"): -0.45,
    ("EUR_USD", "USD_CAD"): -0.61,
    ("GBP_USD", "AUD_USD"): 0.65,
    ("GBP_USD", "NZD_USD"): 0.61,
    ("GBP_USD", "USD_CHF"): -0.85,
    ("GBP_USD", "USD_JPY"): -0.38,
    ("AUD_USD", "NZD_USD"): 0.93,
    ("AUD_USD", "USD_JPY"): 0.32,
    ("USD_JPY", "USD_CAD"): 0.51,
    ("USD_CHF", "USD_JPY"): 0.48,
}


def get_correlation(pair_a: str, pair_b: str) -> float:
    key1 = (pair_a, pair_b)
    key2 = (pair_b, pair_a)
    return _CORRELATIONS.get(key1, _CORRELATIONS.get(key2, 0.0))


def calculate_correlation_risk(open_positions: List[Dict]) -> Dict:
    """
    Analyse correlation risk across open positions.
    Warns when positions are highly correlated (same direction exposure).
    """
    if len(open_positions) < 2:
        return {
            "risk_level":  "low",
            "message":     "Only one position open — no correlation risk",
            "pairs":       [p.get("pair", "") for p in open_positions],
            "correlations": [],
            "warnings":    [],
        }

    pairs      = [p.get("pair", "").replace("/", "_") for p in open_positions]
    directions = [p.get("direction", "BUY").upper() for p in open_positions]
    correlations = []
    warnings     = []

    for i in range(len(pairs)):
        for j in range(i + 1, len(pairs)):
            corr = get_correlation(pairs[i], pairs[j])
            same_dir = directions[i] == directions[j]
            effective_corr = corr if same_dir else -corr

            label = (
                "Strongly Correlated" if abs(effective_corr) >= 0.80
                else "Moderately Correlated" if abs(effective_corr) >= 0.50
                else "Weakly Correlated"
            )

            entry = {
                "pair_a":    pairs[i].replace("_", "/"),
                "pair_b":    pairs[j].replace("_", "/"),
                "correlation": round(effective_corr, 2),
                "direction_a": directions[i],
                "direction_b": directions[j],
                "label":     label,
            }
            correlations.append(entry)

            if abs(effective_corr) >= 0.75:
                warnings.append(
                    f"{pairs[i].replace('_','/')} and {pairs[j].replace('_','/')} "
                    f"are {round(abs(effective_corr)*100):.0f}% correlated — "
                    f"{'amplified' if effective_corr > 0 else 'hedged'} exposure"
                )

    high_corr = [c for c in correlations if abs(c["correlation"]) >= 0.75]
    risk_level = (
        "high"   if len(high_corr) >= 2
        else "medium" if len(high_corr) == 1
        else "low"
    )

    return {
        "risk_level":   risk_level,
        "pairs":        [p.replace("_", "/") for p in pairs],
        "correlations": correlations,
        "warnings":     warnings,
        "message": (
            f"HIGH RISK: {len(warnings)} correlated position pairs detected"
            if risk_level == "high"
            else f"MEDIUM RISK: {warnings[0]}"
            if risk_level == "medium" and warnings
            else "LOW RISK: Positions are well diversified"
        ),
    }


# ── Advanced Monte Carlo with stress testing ──────────────────────────────────

def run_stress_test(
    win_rate: float,
    avg_win: float,
    avg_loss: float,
    starting_balance: float,
    num_trades: int = 100,
    simulations: int = 1000,
) -> Dict:
    """
    Stress test: run Monte Carlo under 3 regimes.
    Normal, Bear (reduced win rate), and Crisis (increased losses).
    """
    import numpy as np

    def _simulate(wr: float, aw: float, al: float) -> Dict:
        rng = np.random.default_rng()
        final_balances = []
        max_drawdowns  = []

        for _ in range(simulations):
            balance = starting_balance
            peak    = balance
            max_dd  = 0.0
            outcomes = rng.random(num_trades)
            for outcome in outcomes:
                balance += aw if outcome < wr else -al
                balance  = max(balance, 0)
                if balance > peak:
                    peak = balance
                dd = (peak - balance) / peak if peak > 0 else 0
                if dd > max_dd:
                    max_dd = dd
            final_balances.append(balance)
            max_drawdowns.append(max_dd)

        fb = np.array(final_balances)
        return {
            "median_final":        round(float(np.median(fb)), 2),
            "prob_profit":         round(float(np.mean(fb > starting_balance)), 4),
            "prob_ruin":           round(float(np.mean(fb <= 0)), 4),
            "median_max_drawdown": round(float(np.median(max_drawdowns)), 4),
        }

    normal = _simulate(win_rate, avg_win, avg_loss)
    bear   = _simulate(win_rate * 0.85, avg_win * 0.90, avg_loss * 1.10)
    crisis = _simulate(win_rate * 0.70, avg_win * 0.75, avg_loss * 1.30)

    return {
        "normal_market": {**normal,  "label": "Normal Market"},
        "bear_market":   {**bear,    "label": "Bear Market (-15% win rate)"},
        "crisis":        {**crisis,  "label": "Crisis (-30% win rate, +30% losses)"},
        "kelly": calculate_kelly(win_rate, avg_win, avg_loss, starting_balance),
        "drawdown_controls": calculate_drawdown_controls(starting_balance),
    }