"""
Tajir AI Risk Guardian — Core Scoring Engine
Phase 17

Three independent scorers feed a weighted composite score.
Hard limits are checked separately — they bypass scoring and block immediately.
"""

from __future__ import annotations
import math
from typing import Optional

from app.risk.risk_models import (
    TradeRequest, AccountSnapshot, MarketSnapshot,
    PositionScore, AccountScore, MarketScore,
    RiskGuardianResult, RiskDecision, TrustLevel,
)


# ─── Hard Limits (bypass scoring — instant BLOCK) ─────────────────────────────

HARD_LIMITS = {
    "max_lot_size":          10.0,    # absolute maximum lots regardless of balance
    "max_leverage":          200,     # if broker allows 500 we still cap at 200
    "max_drawdown_pct":      20.0,    # never trade if account down >20% from peak
    "max_daily_loss_pct":    5.0,     # stop trading if daily loss exceeds 5%
    "max_open_positions":    10,      # no more than 10 concurrent positions
    "max_consecutive_losses": 5,      # cool-down after 5 losses in a row
    "min_stop_loss_pips":    5.0,     # force a stop loss of at least 5 pips
    "news_window_block":     True,    # always block during high-impact news
}

# Trust-level lot caps (multiplier of base account lot limit)
TRUST_LOT_CAPS = {
    TrustLevel.OBSERVE:   0.01,
    TrustLevel.ASSIST:    0.05,
    TrustLevel.SEMI_AUTO: 0.10,
    TrustLevel.FULL_AUTO: 0.20,
}

# Scoring weights for composite
WEIGHTS = {
    "position": 0.45,
    "account":  0.35,
    "market":   0.20,
}


# ─── Position Scorer ──────────────────────────────────────────────────────────

def score_position(
    trade: TradeRequest,
    account: AccountSnapshot,
    pip_value: float = 10.0,   # USD per pip per standard lot — parameterised for currency pairs
) -> PositionScore:
    score = 0.0
    flags: list[str] = []

    # 1. Risk % of balance
    if trade.stop_loss_pips and trade.stop_loss_pips > 0:
        risk_amount = trade.lot_size * pip_value * trade.stop_loss_pips
        lot_risk_pct = (risk_amount / account.balance) * 100 if account.balance > 0 else 100.0
    else:
        # No stop loss — assume full lot value as risk proxy
        lot_risk_pct = (trade.lot_size / (account.balance / 1000)) * 100
        flags.append("No stop loss set — risk estimated from lot size")

    if lot_risk_pct > 10:
        score += 40
        flags.append(f"Risk per trade is {lot_risk_pct:.1f}% of balance (limit: 10%)")
    elif lot_risk_pct > 5:
        score += 20
        flags.append(f"Risk per trade is {lot_risk_pct:.1f}% of balance (recommended: ≤2%)")
    elif lot_risk_pct > 2:
        score += 8

    # 2. Leverage penalty
    if trade.leverage > 100:
        score += 25
        flags.append(f"Leverage {trade.leverage}:1 is very high (recommended: ≤50:1 for beginners)")
    elif trade.leverage > 50:
        score += 12
        flags.append(f"Leverage {trade.leverage}:1 is elevated")

    # 3. Reward-to-risk ratio
    if trade.stop_loss_pips and trade.take_profit_pips:
        rr = trade.take_profit_pips / trade.stop_loss_pips
        if rr < 1.0:
            score += 15
            flags.append(f"Risk:Reward ratio {rr:.2f} — TP is smaller than SL")
        elif rr < 1.5:
            score += 5

    # 4. Trust-level lot cap
    max_safe_lots = TRUST_LOT_CAPS[trade.trust_level] * (account.balance / 1000)
    if trade.lot_size > max_safe_lots:
        score += 20
        flags.append(
            f"Lot size {trade.lot_size} exceeds trust-level cap of {max_safe_lots:.2f} "
            f"for {trade.trust_level.value} mode"
        )

    margin_used = (trade.lot_size * 100_000) / trade.leverage

    return PositionScore(
        score=min(score, 100),
        flags=flags,
        lot_risk_pct=round(lot_risk_pct, 2),
        margin_used=round(margin_used, 2),
    )


# ─── Account Scorer ───────────────────────────────────────────────────────────

def score_account(account: AccountSnapshot) -> AccountScore:
    score = 0.0
    flags: list[str] = []

    # 1. Current drawdown
    if account.current_drawdown_pct > 15:
        score += 35
        flags.append(f"Account drawdown {account.current_drawdown_pct:.1f}% — near hard limit (20%)")
    elif account.current_drawdown_pct > 10:
        score += 20
        flags.append(f"Account drawdown {account.current_drawdown_pct:.1f}% — caution zone")
    elif account.current_drawdown_pct > 5:
        score += 8

    # 2. Daily loss
    if account.daily_loss_pct > 3:
        score += 30
        flags.append(f"Daily loss {account.daily_loss_pct:.1f}% — nearing daily limit (5%)")
    elif account.daily_loss_pct > 1.5:
        score += 12

    # 3. Consecutive losses (emotional / system trading signal)
    if account.consecutive_losses >= 4:
        score += 20
        flags.append(f"{account.consecutive_losses} consecutive losses — consider pausing")
    elif account.consecutive_losses >= 2:
        score += 8
        flags.append(f"{account.consecutive_losses} consecutive losses")

    # 4. Win rate penalty (recent poor performance)
    if account.win_rate_7d < 35:
        score += 15
        flags.append(f"7-day win rate {account.win_rate_7d:.0f}% is below baseline (50%)")
    elif account.win_rate_7d < 45:
        score += 5

    # 5. Too many open positions — correlation risk
    if account.open_positions >= 8:
        score += 10
        flags.append(f"{account.open_positions} positions open — high correlation risk")

    return AccountScore(score=min(score, 100), flags=flags)


# ─── Market Scorer ────────────────────────────────────────────────────────────

def score_market(market: MarketSnapshot) -> MarketScore:
    score = 0.0
    flags: list[str] = []

    # 1. Spread cost (cost of entry as % of ATR)
    if market.atr_14 > 0:
        spread_ratio = market.current_spread_pips / market.atr_14
        if spread_ratio > 0.3:
            score += 30
            flags.append(f"Spread ({market.current_spread_pips:.1f} pips) is {spread_ratio*100:.0f}% of ATR — high cost")
        elif spread_ratio > 0.15:
            score += 12
            flags.append(f"Spread elevated relative to ATR")

    # 2. News window
    if market.is_news_window:
        score += 40
        flags.append("High-impact news event within ±30 minutes")

    # 3. Volatility
    if market.volatility_index > 80:
        score += 20
        flags.append(f"Market volatility is extreme ({market.volatility_index:.0f}/100)")
    elif market.volatility_index > 60:
        score += 10
        flags.append(f"Market volatility is elevated ({market.volatility_index:.0f}/100)")

    # 4. Session quality
    if market.session == "dead":
        score += 15
        flags.append("Market is in dead zone — low liquidity, erratic moves")
    elif market.session == "sydney":
        score += 5

    return MarketScore(score=min(score, 100), flags=flags)


# ─── Hard Limit Checker ───────────────────────────────────────────────────────

def check_hard_limits(
    trade: TradeRequest,
    account: AccountSnapshot,
    market: MarketSnapshot,
) -> list[str]:
    violations: list[str] = []

    if trade.lot_size > HARD_LIMITS["max_lot_size"]:
        violations.append(f"Lot size {trade.lot_size} exceeds maximum allowed ({HARD_LIMITS['max_lot_size']})")

    if trade.leverage > HARD_LIMITS["max_leverage"]:
        violations.append(f"Leverage {trade.leverage}:1 exceeds platform maximum ({HARD_LIMITS['max_leverage']}:1)")

    if account.current_drawdown_pct >= HARD_LIMITS["max_drawdown_pct"]:
        violations.append(f"Account drawdown {account.current_drawdown_pct:.1f}% has reached the hard stop ({HARD_LIMITS['max_drawdown_pct']}%)")

    if account.daily_loss_pct >= HARD_LIMITS["max_daily_loss_pct"]:
        violations.append(f"Daily loss limit reached ({account.daily_loss_pct:.1f}% ≥ {HARD_LIMITS['max_daily_loss_pct']}%) — no more trades today")

    if account.open_positions >= HARD_LIMITS["max_open_positions"]:
        violations.append(f"Maximum open positions reached ({HARD_LIMITS['max_open_positions']})")

    if account.consecutive_losses >= HARD_LIMITS["max_consecutive_losses"]:
        violations.append(f"{account.consecutive_losses} consecutive losses — trading paused for your protection")

    if trade.stop_loss_pips is not None and trade.stop_loss_pips < HARD_LIMITS["min_stop_loss_pips"]:
        violations.append(f"Stop loss {trade.stop_loss_pips} pips is below minimum ({HARD_LIMITS['min_stop_loss_pips']} pips)")

    if market.is_news_window and HARD_LIMITS["news_window_block"]:
        violations.append("Trade blocked: high-impact news event in progress")

    return violations


# ─── Composite Scorer ─────────────────────────────────────────────────────────

def compute_composite(pos: PositionScore, acc: AccountScore, mkt: MarketScore) -> float:
    raw = (
        pos.score * WEIGHTS["position"] +
        acc.score * WEIGHTS["account"]  +
        mkt.score * WEIGHTS["market"]
    )
    return round(min(raw, 100), 1)


def score_to_decision(score: float) -> RiskDecision:
    if score < 40:
        return RiskDecision.APPROVE
    elif score < 70:
        return RiskDecision.WARN
    return RiskDecision.BLOCK


# ─── Explanation Generator ────────────────────────────────────────────────────

def generate_explanation(
    decision: RiskDecision,
    composite: float,
    pos: PositionScore,
    acc: AccountScore,
    mkt: MarketScore,
    hard_limits: list[str],
) -> str:
    if hard_limits:
        return (
            f"This trade has been blocked because a safety rule was triggered: "
            f"{hard_limits[0]} "
            f"These rules exist to protect your account from serious loss."
        )

    top_flags = (pos.flags + acc.flags + mkt.flags)[:2]
    flag_text = " ".join(top_flags) if top_flags else "All checks passed."

    if decision == RiskDecision.APPROVE:
        return (
            f"Risk score {composite:.0f}/100 — this trade looks acceptable. "
            f"{flag_text}"
        )
    elif decision == RiskDecision.WARN:
        return (
            f"Risk score {composite:.0f}/100 — this trade has elevated risk. "
            f"{flag_text} "
            f"Review the details below before confirming."
        )
    return (
        f"Risk score {composite:.0f}/100 — this trade has been blocked. "
        f"{flag_text} "
        f"Consider reducing lot size or waiting for better conditions."
    )


# ─── Suggested Safer Lot Size ─────────────────────────────────────────────────

def suggest_safer_lot(
    trade: TradeRequest,
    account: AccountSnapshot,
    pip_value: float = 10.0,
    target_risk_pct: float = 2.0,
) -> Optional[float]:
    """Return a lot size that keeps risk at 2% of balance."""
    if not trade.stop_loss_pips or trade.stop_loss_pips <= 0:
        return None
    max_risk = (target_risk_pct / 100) * account.balance
    safe_lots = max_risk / (pip_value * trade.stop_loss_pips)
    return round(max(safe_lots, 0.01), 2)


# ─── Main Entry Point ─────────────────────────────────────────────────────────

def evaluate_trade(
    trade: TradeRequest,
    account: AccountSnapshot,
    market: MarketSnapshot,
    pip_value: float = 10.0,
) -> RiskGuardianResult:
    """
    Full risk evaluation pipeline.
    Called by the FastAPI middleware before any trade is forwarded to broker.
    """

    # Step 1: Hard limits first (fastest exit, most critical)
    hard_limits = check_hard_limits(trade, account, market)
    if hard_limits:
        return RiskGuardianResult(
            composite_score=100.0,
            decision=RiskDecision.BLOCK,
            position_score=PositionScore(score=100, flags=hard_limits, lot_risk_pct=0, margin_used=0),
            account_score=AccountScore(score=0, flags=[]),
            market_score=MarketScore(score=0, flags=[]),
            explanation=generate_explanation(RiskDecision.BLOCK, 100, 
                PositionScore(score=100, flags=[], lot_risk_pct=0, margin_used=0),
                AccountScore(score=0, flags=[]),
                MarketScore(score=0, flags=[]),
                hard_limits,
            ),
            hard_limits_hit=hard_limits,
            approved=False,
        )

    # Step 2: Three independent scorers
    pos_score = score_position(trade, account, pip_value)
    acc_score = score_account(account)
    mkt_score = score_market(market)

    # Step 3: Composite + decision
    composite  = compute_composite(pos_score, acc_score, mkt_score)
    decision   = score_to_decision(composite)
    approved   = decision == RiskDecision.APPROVE

    # Step 4: Explanation + safe suggestion
    explanation = generate_explanation(decision, composite, pos_score, acc_score, mkt_score, [])
    safer_lot   = suggest_safer_lot(trade, account, pip_value) if decision != RiskDecision.APPROVE else None

    return RiskGuardianResult(
        composite_score=composite,
        decision=decision,
        position_score=pos_score,
        account_score=acc_score,
        market_score=mkt_score,
        explanation=explanation,
        suggested_lot_size=safer_lot,
        hard_limits_hit=[],
        approved=approved,
    )