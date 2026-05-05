"""
order_state_machine.py — Defines valid order lifecycle states and transitions.
Prevents invalid state changes and provides audit trail for every transition.
"""

import logging
from enum import Enum
from datetime import datetime, timezone
from typing import Optional

logger = logging.getLogger(__name__)


class OrderState(str, Enum):
    # Initial states
    PENDING = "pending"                         # Created, awaiting risk check
    RISK_APPROVED = "risk_approved"             # Passed risk guardian
    RISK_REJECTED = "risk_rejected"             # Blocked by risk guardian

    # Execution states
    SENT_TO_BROKER = "sent_to_broker"           # Transmitted to Pepperstone
    ACKNOWLEDGED = "acknowledged"               # Broker acknowledged receipt
    PARTIALLY_FILLED = "partially_filled"       # Some quantity executed
    FILLED = "filled"                           # Fully executed
    
    # Terminal failure states
    BROKER_REJECTED = "broker_rejected"         # Broker refused the order
    EXPIRED = "expired"                         # Time-in-force expired
    CANCELLED_BY_USER = "cancelled_by_user"     # User cancelled
    CANCELLED_BY_SYSTEM = "cancelled_by_system" # System cancelled (risk breach)
    
    # Error states
    EXECUTION_ERROR = "execution_error"         # Technical failure during execution
    TIMEOUT = "timeout"                         # No response from broker within SLA


# Valid state transitions
VALID_TRANSITIONS: dict[OrderState, set[OrderState]] = {
    OrderState.PENDING: {
        OrderState.RISK_APPROVED,
        OrderState.RISK_REJECTED,
        OrderState.CANCELLED_BY_USER,
    },
    OrderState.RISK_APPROVED: {
        OrderState.SENT_TO_BROKER,
        OrderState.CANCELLED_BY_USER,
        OrderState.CANCELLED_BY_SYSTEM,
        OrderState.EXECUTION_ERROR,
    },
    OrderState.SENT_TO_BROKER: {
        OrderState.ACKNOWLEDGED,
        OrderState.FILLED,
        OrderState.PARTIALLY_FILLED,
        OrderState.BROKER_REJECTED,
        OrderState.TIMEOUT,
        OrderState.EXECUTION_ERROR,
    },
    OrderState.ACKNOWLEDGED: {
        OrderState.FILLED,
        OrderState.PARTIALLY_FILLED,
        OrderState.BROKER_REJECTED,
        OrderState.EXPIRED,
        OrderState.CANCELLED_BY_USER,
        OrderState.CANCELLED_BY_SYSTEM,
    },
    OrderState.PARTIALLY_FILLED: {
        OrderState.FILLED,
        OrderState.CANCELLED_BY_USER,
        OrderState.CANCELLED_BY_SYSTEM,
        OrderState.EXPIRED,
    },
    # Terminal states — no transitions out
    OrderState.FILLED: set(),
    OrderState.RISK_REJECTED: set(),
    OrderState.BROKER_REJECTED: set(),
    OrderState.EXPIRED: set(),
    OrderState.CANCELLED_BY_USER: set(),
    OrderState.CANCELLED_BY_SYSTEM: set(),
    OrderState.EXECUTION_ERROR: set(),
    OrderState.TIMEOUT: set(),
}


class OrderStateTransitionError(Exception):
    """Raised when an invalid state transition is attempted."""
    pass


class OrderStateMachine:
    """
    Manages the lifecycle of a single order.
    
    Usage:
        machine = OrderStateMachine(order_id="ORD-12345", initial_state=OrderState.PENDING)
        machine.transition(OrderState.RISK_APPROVED, reason="Guardian approved")
        machine.transition(OrderState.SENT_TO_BROKER, reason="Submitted to Pepperstone")
    """

    def __init__(self, order_id: str, initial_state: OrderState = OrderState.PENDING):
        self.order_id = order_id
        self.current_state = initial_state
        self.history: list[dict] = [
            {
                "from_state": None,
                "to_state": initial_state.value,
                "timestamp": datetime.now(timezone.utc).isoformat(),
                "reason": "Order created",
            }
        ]

    def transition(self, new_state: OrderState, reason: Optional[str] = None) -> bool:
        """
        Attempt to transition to a new state.
        Raises OrderStateTransitionError if the transition is invalid.
        """
        valid_next = VALID_TRANSITIONS.get(self.current_state, set())

        if new_state not in valid_next:
            error_msg = (
                f"Order {self.order_id}: Invalid transition "
                f"{self.current_state.value} → {new_state.value}. "
                f"Valid transitions: {[s.value for s in valid_next]}"
            )
            logger.error(error_msg)
            raise OrderStateTransitionError(error_msg)

        old_state = self.current_state
        self.current_state = new_state

        transition_record = {
            "from_state": old_state.value,
            "to_state": new_state.value,
            "timestamp": datetime.now(timezone.utc).isoformat(),
            "reason": reason or "No reason provided",
        }
        self.history.append(transition_record)

        logger.info(
            "Order %s: %s → %s | reason: %s",
            self.order_id, old_state.value, new_state.value, reason,
        )
        return True

    @property
    def is_terminal(self) -> bool:
        return len(VALID_TRANSITIONS.get(self.current_state, set())) == 0

    @property
    def is_active(self) -> bool:
        return self.current_state in {
            OrderState.PENDING,
            OrderState.RISK_APPROVED,
            OrderState.SENT_TO_BROKER,
            OrderState.ACKNOWLEDGED,
            OrderState.PARTIALLY_FILLED,
        }

    def to_dict(self) -> dict:
        return {
            "order_id": self.order_id,
            "current_state": self.current_state.value,
            "is_terminal": self.is_terminal,
            "is_active": self.is_active,
            "history": self.history,
        }
