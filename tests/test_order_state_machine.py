"""
test_order_state_machine.py — Tests for order lifecycle state management.
"""

import pytest
from app.services.order_state_machine import (
    OrderState,
    OrderStateMachine,
    OrderStateTransitionError,
)


class TestOrderStateMachine:
    """Test valid and invalid state transitions."""

    def test_initial_state(self):
        machine = OrderStateMachine("ORD-001")
        assert machine.current_state == OrderState.PENDING
        assert machine.is_active is True
        assert machine.is_terminal is False

    def test_valid_full_lifecycle(self):
        machine = OrderStateMachine("ORD-002")
        machine.transition(OrderState.RISK_APPROVED, reason="Guardian OK")
        machine.transition(OrderState.SENT_TO_BROKER, reason="FIX submitted")
        machine.transition(OrderState.ACKNOWLEDGED, reason="Broker ACK")
        machine.transition(OrderState.FILLED, reason="Full fill at 1.0900")
        
        assert machine.current_state == OrderState.FILLED
        assert machine.is_terminal is True
        assert machine.is_active is False
        assert len(machine.history) == 5  # initial + 4 transitions

    def test_risk_rejection(self):
        machine = OrderStateMachine("ORD-003")
        machine.transition(OrderState.RISK_REJECTED, reason="Daily loss limit exceeded")
        
        assert machine.current_state == OrderState.RISK_REJECTED
        assert machine.is_terminal is True

    def test_invalid_transition_raises(self):
        machine = OrderStateMachine("ORD-004")
        with pytest.raises(OrderStateTransitionError):
            # Can't go from PENDING directly to FILLED
            machine.transition(OrderState.FILLED)

    def test_no_transition_from_terminal(self):
        machine = OrderStateMachine("ORD-005")
        machine.transition(OrderState.RISK_REJECTED, reason="Blocked")
        
        with pytest.raises(OrderStateTransitionError):
            machine.transition(OrderState.RISK_APPROVED)

    def test_partial_fill_to_fill(self):
        machine = OrderStateMachine("ORD-006")
        machine.transition(OrderState.RISK_APPROVED)
        machine.transition(OrderState.SENT_TO_BROKER)
        machine.transition(OrderState.PARTIALLY_FILLED, reason="0.5 of 1.0 lots filled")
        machine.transition(OrderState.FILLED, reason="Remaining 0.5 lots filled")
        
        assert machine.current_state == OrderState.FILLED

    def test_user_cancellation_from_acknowledged(self):
        machine = OrderStateMachine("ORD-007")
        machine.transition(OrderState.RISK_APPROVED)
        machine.transition(OrderState.SENT_TO_BROKER)
        machine.transition(OrderState.ACKNOWLEDGED)
        machine.transition(OrderState.CANCELLED_BY_USER, reason="User requested cancel")
        
        assert machine.is_terminal is True

    def test_history_tracking(self):
        machine = OrderStateMachine("ORD-008")
        machine.transition(OrderState.RISK_APPROVED, reason="Test reason")
        
        history = machine.to_dict()["history"]
        assert len(history) == 2
        assert history[1]["from_state"] == "pending"
        assert history[1]["to_state"] == "risk_approved"
        assert history[1]["reason"] == "Test reason"
        assert "timestamp" in history[1]

    def test_timeout_state(self):
        machine = OrderStateMachine("ORD-009")
        machine.transition(OrderState.RISK_APPROVED)
        machine.transition(OrderState.SENT_TO_BROKER)
        machine.transition(OrderState.TIMEOUT, reason="No response in 30s")
        
        assert machine.is_terminal is True
