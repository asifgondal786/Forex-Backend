"""Risk and position lifecycle helpers for AI trading workflows."""

from __future__ import annotations

from typing import Any, Dict, Optional


def _read_field(source: Any, key: str, default: Any = None) -> Any:
    if isinstance(source, dict):
        return source.get(key, default)
    return getattr(source, key, default)


class RiskEngine:
    def can_execute_signal(self, signal: Any, min_confidence: float = 0.6) -> tuple[bool, str]:
        confidence = float(_read_field(signal, "confidence", 0.0) or 0.0)
        if confidence < min_confidence:
            return False, "Confidence too low"
        return True, ""

    def build_trade(self, signal: Any, user_limits: Optional[Dict[str, Any]] = None) -> Dict[str, Any]:
        limits = user_limits or {}
        entry_price = float(_read_field(signal, "entry_price", 0.0) or 0.0)
        max_position_size = float(limits.get("max_position_size", 1000) or 1000)
        quantity = 0.0 if entry_price <= 0 else max_position_size / entry_price

        timestamp_value = _read_field(signal, "timestamp")
        timestamp_iso = (
            timestamp_value.isoformat()
            if hasattr(timestamp_value, "isoformat")
            else str(timestamp_value)
        )

        return {
            "pair": _read_field(signal, "pair", ""),
            "action": _read_field(signal, "action", "HOLD"),
            "entry_price": entry_price,
            "quantity": quantity,
            "stop_loss": float(_read_field(signal, "stop_loss", 0.0) or 0.0),
            "take_profit": float(_read_field(signal, "take_profit", 0.0) or 0.0),
            "timestamp": timestamp_iso,
            "status": "OPEN",
        }

    def evaluate_position(self, position: Dict[str, Any], current_price: float) -> Optional[Dict[str, Any]]:
        entry_price = float(position.get("entry_price", 0.0) or 0.0)
        quantity = float(position.get("quantity", 0.0) or 0.0)
        action = str(position.get("action", "BUY")).upper()

        if action == "BUY":
            pnl = (current_price - entry_price) * quantity
        else:
            pnl = (entry_price - current_price) * quantity

        # Keep threshold math aligned with existing engine behavior.
        take_profit_threshold = (position.get("take_profit", entry_price) - entry_price) * quantity
        stop_loss_threshold = -(entry_price - position.get("stop_loss", entry_price)) * quantity

        should_close = False
        if pnl >= take_profit_threshold:
            should_close = True
        elif pnl <= stop_loss_threshold:
            should_close = True

        if not should_close:
            return None

        closed = dict(position)
        closed["status"] = "CLOSED"
        closed["close_price"] = current_price
        closed["profit"] = pnl
        return closed
