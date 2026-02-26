from datetime import datetime, timezone
from types import SimpleNamespace

from app.ai.gemini_client import GeminiClient, _extract_json_block
from app.ai.risk_engine import RiskEngine
from app.ai.strategy_engine import StrategyEngine


def test_strategy_engine_generates_buy_signal():
    engine = StrategyEngine()
    market_condition = SimpleNamespace(
        current_price=1.1000,
        rsi=25.0,
        trend="BULLISH",
        support_level=1.0950,
        resistance_level=1.1200,
        macd={"histogram": 0.01},
    )

    decision = engine.generate_signal(market_condition)

    assert decision.action == "BUY"
    assert decision.confidence > 0.5
    assert decision.entry_price == 1.1000


def test_strategy_engine_generates_sell_signal():
    engine = StrategyEngine()
    market_condition = {
        "current_price": 1.2000,
        "rsi": 80.0,
        "trend": "BEARISH",
        "support_level": 1.1500,
        "resistance_level": 1.2050,
        "macd": {"histogram": -0.02},
    }

    decision = engine.generate_signal(market_condition)

    assert decision.action == "SELL"
    assert decision.confidence > 0.5
    assert decision.stop_loss == 1.2050


def test_risk_engine_blocks_low_confidence():
    engine = RiskEngine()
    signal = SimpleNamespace(confidence=0.2)

    allowed, reason = engine.can_execute_signal(signal, min_confidence=0.6)

    assert allowed is False
    assert reason == "Confidence too low"


def test_risk_engine_build_trade_handles_zero_entry_price():
    engine = RiskEngine()
    signal = SimpleNamespace(
        pair="EUR/USD",
        action="BUY",
        entry_price=0.0,
        stop_loss=0.0,
        take_profit=0.0,
        timestamp=datetime.now(timezone.utc),
    )

    trade = engine.build_trade(signal, {"max_position_size": 1000})

    assert trade["quantity"] == 0.0
    assert trade["status"] == "OPEN"


def test_risk_engine_closes_buy_position_on_take_profit():
    engine = RiskEngine()
    position = {
        "action": "BUY",
        "entry_price": 1.0,
        "quantity": 1000.0,
        "take_profit": 1.01,
        "stop_loss": 0.99,
    }

    closed = engine.evaluate_position(position, current_price=1.02)

    assert closed is not None
    assert closed["status"] == "CLOSED"
    assert closed["profit"] > 0


def test_extract_json_block_strips_markdown_fence():
    raw = "```json\n{\"ok\": true}\n```"
    cleaned = _extract_json_block(raw)
    assert cleaned == "{\"ok\": true}"


def test_gemini_client_generate_json_uses_fallback_on_parse_error():
    client = GeminiClient(api_key=None)
    client._available = True
    client.generate_text = lambda **kwargs: "not-json"

    result = client.generate_json(
        model_name="gemini-2.0-flash",
        prompt="test",
        fallback={"status": "fallback"},
    )

    assert result == {"status": "fallback"}


def test_gemini_client_generate_json_parses_fenced_json():
    client = GeminiClient(api_key=None)
    client._available = True
    client.generate_text = lambda **kwargs: "```json\n{\"action\":\"BUY\"}\n```"

    result = client.generate_json(
        model_name="gemini-2.0-flash",
        prompt="test",
        fallback={"status": "fallback"},
    )

    assert result["action"] == "BUY"
