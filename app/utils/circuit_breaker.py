"""
circuit_breaker.py — Prevents cascading failures when external services are down.
Implements the Circuit Breaker pattern (closed → open → half-open).
"""

import time
import logging
from enum import Enum
from typing import Callable, Any
from functools import wraps

logger = logging.getLogger(__name__)


class CircuitState(str, Enum):
    CLOSED = "closed"          # Normal operation
    OPEN = "open"              # Blocking all calls (service is down)
    HALF_OPEN = "half_open"    # Testing if service recovered


class CircuitBreaker:
    """
    Usage:

        async def fetch_price(pair: str):
            ...
    """

    def __init__(
        self,
        name: str,
        failure_threshold: int = 5,
        recovery_timeout: int = 60,
        success_threshold: int = 2,
    ):
        self.name = name
        self.failure_threshold = failure_threshold
        self.recovery_timeout = recovery_timeout
        self.success_threshold = success_threshold

        self._state = CircuitState.CLOSED
        self._failure_count = 0
        self._success_count = 0
        self._last_failure_time = 0.0
        self._last_state_change = time.time()

    @property
    def state(self) -> CircuitState:
        if self._state == CircuitState.OPEN:
            # Check if recovery timeout has elapsed
            if time.time() - self._last_failure_time >= self.recovery_timeout:
                self._transition(CircuitState.HALF_OPEN)
        return self._state

    def _transition(self, new_state: CircuitState):
        old_state = self._state
        self._state = new_state
        self._last_state_change = time.time()
        logger.info(
            "CircuitBreaker[%s] %s → %s (failures=%d)",
            self.name, old_state.value, new_state.value, self._failure_count,
        )

    def _record_success(self):
        if self._state == CircuitState.HALF_OPEN:
            self._success_count += 1
            if self._success_count >= self.success_threshold:
                self._failure_count = 0
                self._success_count = 0
                self._transition(CircuitState.CLOSED)
        else:
            self._failure_count = 0
            self._success_count = 0

    def _record_failure(self):
        self._failure_count += 1
        self._success_count = 0
        self._last_failure_time = time.time()

        if self._failure_count >= self.failure_threshold:
            self._transition(CircuitState.OPEN)

    def __call__(self, func: Callable) -> Callable:
        @wraps(func)
        async def wrapper(*args, **kwargs) -> Any:
            current_state = self.state

            if current_state == CircuitState.OPEN:
                raise CircuitBreakerOpenError(
                    f"CircuitBreaker[{self.name}] is OPEN — "
                    f"service unavailable, retry after {self.recovery_timeout}s"
                )

            try:
                result = await func(*args, **kwargs)
                self._record_success()
                return result
            except Exception as e:
                self._record_failure()
                logger.warning(
                    "CircuitBreaker[%s] failure #%d: %s",
                    self.name, self._failure_count, e,
                )
                raise

        # Expose breaker state on the wrapper for monitoring
        wrapper.breaker = self
        return wrapper

    def get_status(self) -> dict:
        return {
            "name": self.name,
            "state": self.state.value,
            "failure_count": self._failure_count,
            "failure_threshold": self.failure_threshold,
            "recovery_timeout": self.recovery_timeout,
            "last_failure": self._last_failure_time,
        }


class CircuitBreakerOpenError(Exception):
    """Raised when attempting to call through an open circuit breaker."""
    pass


# ─── Pre-configured breakers for external services ────────────────────────────

anthropic_breaker = CircuitBreaker("Anthropic", failure_threshold=3, recovery_timeout=90)
deepseek_breaker = CircuitBreaker("DeepSeek", failure_threshold=3, recovery_timeout=90)
pepperstone_breaker = CircuitBreaker("Pepperstone", failure_threshold=2, recovery_timeout=120)
stripe_breaker = CircuitBreaker("Stripe", failure_threshold=3, recovery_timeout=60)
twilio_breaker = CircuitBreaker("Twilio", failure_threshold=5, recovery_timeout=120)
