"""Rule-based strategy engine separated from API and transport layers."""

from __future__ import annotations

from dataclasses import dataclass
from typing import Any


def _read_field(source: Any, key: str, default: Any = None) -> Any:
    if isinstance(source, dict):
        return source.get(key, default)
    return getattr(source, key, default)


@dataclass
class SignalDecision:
    action: str
    confidence: float
    reason: str
    entry_price: float
    stop_loss: float
    take_profit: float


class StrategyEngine:
    """Generates trading signal decisions from market conditions."""

    def generate_signal(self, market_condition: Any) -> SignalDecision:
        action = "HOLD"
        confidence = 0.0
        reason = ""
        entry_price = float(_read_field(market_condition, "current_price", 0.0) or 0.0)
        stop_loss = 0.0
        take_profit = 0.0

        rsi = float(_read_field(market_condition, "rsi", 50.0) or 50.0)
        trend = str(_read_field(market_condition, "trend", "SIDEWAYS") or "SIDEWAYS")
        support = float(_read_field(market_condition, "support_level", entry_price) or entry_price)
        resistance = float(_read_field(market_condition, "resistance_level", entry_price) or entry_price)
        macd = _read_field(market_condition, "macd", {}) or {}
        histogram = float((macd.get("histogram") if isinstance(macd, dict) else 0.0) or 0.0)

        signals = []

        if rsi < 30:
            signals.append(("BUY", 0.7, "RSI oversold"))
        elif rsi > 70:
            signals.append(("SELL", 0.7, "RSI overbought"))

        if histogram > 0:
            signals.append(("BUY", 0.6, "MACD bullish crossover"))
        elif histogram < 0:
            signals.append(("SELL", 0.6, "MACD bearish crossover"))

        if trend == "BULLISH":
            signals.append(("BUY", 0.8, "Strong uptrend"))
        elif trend == "BEARISH":
            signals.append(("SELL", 0.8, "Strong downtrend"))

        if entry_price <= support * 1.01:
            signals.append(("BUY", 0.9, "Price at support"))
        elif entry_price >= resistance * 0.99:
            signals.append(("SELL", 0.9, "Price at resistance"))

        if signals:
            buy_signals = [s for s in signals if s[0] == "BUY"]
            sell_signals = [s for s in signals if s[0] == "SELL"]

            buy_confidence = sum(s[1] for s in buy_signals) / len(signals)
            sell_confidence = sum(s[1] for s in sell_signals) / len(signals)

            if buy_confidence > sell_confidence and buy_confidence > 0.5:
                action = "BUY"
                confidence = buy_confidence
                reason = ", ".join(s[2] for s in buy_signals)
                stop_loss = support
                take_profit = entry_price * 1.02
            elif sell_confidence > buy_confidence and sell_confidence > 0.5:
                action = "SELL"
                confidence = sell_confidence
                reason = ", ".join(s[2] for s in sell_signals)
                stop_loss = resistance
                take_profit = entry_price * 0.98

        return SignalDecision(
            action=action,
            confidence=confidence,
            reason=reason,
            entry_price=entry_price,
            stop_loss=stop_loss,
            take_profit=take_profit,
        )
