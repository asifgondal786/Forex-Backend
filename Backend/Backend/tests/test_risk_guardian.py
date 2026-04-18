"""
Tajir Phase 17 â€” Risk Guardian Unit Tests
Run with: pytest test_risk_guardian.py -v
"""

import sys
sys.path.insert(0, ".")

import pytest
from risk_models import (
    TradeRequest, AccountSnapshot, MarketSnapshot,
    RiskDecision, TrustLevel, TradeDirection,
)
from risk_guardian import (
    evaluate_trade, check_hard_limits,
    score_position, score_account, score_market,
)


# â”€â”€â”€ Fixtures â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

def safe_trade() -> TradeRequest:
    return TradeRequest(
        user_id="test_user",
        symbol="EURUSD",
        direction=TradeDirection.BUY,
        lot_size=0.05,
        leverage=10,
        stop_loss_pips=20.0,
        take_profit_pips=40.0,
        trust_level=TrustLevel.ASSIST,
        source="manual",
    )

def healthy_account() -> AccountSnapshot:
    return AccountSnapshot(
        balance=10_000.0,
        equity=10_100.0,
        current_drawdown_pct=2.0,
        daily_loss_pct=0.5,
        open_positions=2,
        win_rate_7d=60.0,
        consecutive_losses=0,
    )

def normal_market() -> MarketSnapshot:
    return MarketSnapshot(
        symbol="EURUSD",
        current_spread_pips=1.0,
        atr_14=8.0,
        is_news_window=False,
        session="london",
        volatility_index=30.0,
    )


# â”€â”€â”€ Hard Limit Tests â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

class TestHardLimits:

    def test_no_violations_on_safe_trade(self):
        violations = check_hard_limits(safe_trade(), healthy_account(), normal_market())
        assert violations == []

    def test_max_drawdown_triggers(self):
        acc = healthy_account()
        acc.current_drawdown_pct = 21.0
        violations = check_hard_limits(safe_trade(), acc, normal_market())
        assert any("drawdown" in v.lower() for v in violations)

    def test_daily_loss_triggers(self):
        acc = healthy_account()
        acc.daily_loss_pct = 5.5
        violations = check_hard_limits(safe_trade(), acc, normal_market())
        assert any("daily loss" in v.lower() for v in violations)

    def test_consecutive_losses_triggers(self):
        acc = healthy_account()
        acc.consecutive_losses = 5
        violations = check_hard_limits(safe_trade(), acc, normal_market())
        assert any("consecutive" in v.lower() for v in violations)

    def test_news_window_blocks(self):
        mkt = normal_market()
        mkt.is_news_window = True
        violations = check_hard_limits(safe_trade(), mkt_snapshot=mkt, account=healthy_account())
        assert any("news" in v.lower() for v in violations)

    def test_overleveraged_trade(self):
        t = safe_trade()
        t.leverage = 201
        violations = check_hard_limits(t, healthy_account(), normal_market())
        assert any("leverage" in v.lower() for v in violations)


# â”€â”€â”€ Score Tests â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

class TestPositionScorer:

    def test_safe_trade_low_score(self):
        result = score_position(safe_trade(), healthy_account())
        assert result.score < 20

    def test_high_leverage_adds_score(self):
        t = safe_trade()
        t.leverage = 200
        result = score_position(t, healthy_account())
        assert result.score >= 25

    def test_bad_rr_adds_score(self):
        t = safe_trade()
        t.stop_loss_pips = 40.0
        t.take_profit_pips = 10.0  # TP < SL
        result = score_position(t, healthy_account())
        assert result.score > 10
        assert any("reward" in f.lower() or "risk" in f.lower() for f in result.flags)

    def test_no_stop_loss_flags(self):
        t = safe_trade()
        t.stop_loss_pips = None
        result = score_position(t, healthy_account())
        assert any("stop loss" in f.lower() for f in result.flags)


class TestAccountScorer:

    def test_healthy_account_low_score(self):
        result = score_account(healthy_account())
        assert result.score < 15

    def test_high_drawdown_scores_high(self):
        acc = healthy_account()
        acc.current_drawdown_pct = 17.0
        result = score_account(acc)
        assert result.score >= 35

    def test_low_win_rate_adds_score(self):
        acc = healthy_account()
        acc.win_rate_7d = 30.0
        result = score_account(acc)
        assert result.score >= 15


class TestMarketScorer:

    def test_normal_market_low_score(self):
        result = score_market(normal_market())
        assert result.score < 15

    def test_news_window_high_score(self):
        mkt = normal_market()
        mkt.is_news_window = True
        result = score_market(mkt)
        assert result.score >= 40

    def test_high_volatility_adds_score(self):
        mkt = normal_market()
        mkt.volatility_index = 85
        result = score_market(mkt)
        assert result.score >= 20

    def test_dead_session_adds_score(self):
        mkt = normal_market()
        mkt.session = "dead"
        result = score_market(mkt)
        assert result.score >= 15


# â”€â”€â”€ Full Pipeline Tests â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

class TestEvaluateTrade:

    def test_safe_trade_approved(self):
        result = evaluate_trade(safe_trade(), healthy_account(), normal_market())
        assert result.decision == RiskDecision.APPROVE
        assert result.approved is True
        assert result.composite_score < 40

    def test_hard_limit_overrides_scoring(self):
        acc = healthy_account()
        acc.current_drawdown_pct = 21.0  # triggers hard limit
        result = evaluate_trade(safe_trade(), acc, normal_market())
        assert result.decision == RiskDecision.BLOCK
        assert len(result.hard_limits_hit) > 0
        assert result.composite_score == 100.0

    def test_risky_trade_warns(self):
        t = safe_trade()
        t.lot_size = 0.5
        t.leverage = 100
        t.stop_loss_pips = 5.0
        t.take_profit_pips = 3.0
        acc = healthy_account()
        acc.current_drawdown_pct = 8.0
        acc.consecutive_losses = 3
        result = evaluate_trade(t, acc, normal_market())
        assert result.decision in (RiskDecision.WARN, RiskDecision.BLOCK)

    def test_explanation_populated(self):
        result = evaluate_trade(safe_trade(), healthy_account(), normal_market())
        assert len(result.explanation) > 20

    def test_suggested_lot_when_warn(self):
        t = safe_trade()
        t.lot_size = 2.0
        t.leverage = 100
        acc = healthy_account()
        acc.current_drawdown_pct = 12.0
        result = evaluate_trade(t, acc, normal_market())
        if result.decision == RiskDecision.WARN:
            assert result.suggested_lot_size is not None
            assert result.suggested_lot_size < t.lot_size