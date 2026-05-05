"""
test_circuit_breaker.py — Tests for the circuit breaker pattern implementation.
"""

import pytest
from unittest.mock import AsyncMock
from app.utils.circuit_breaker import (
    CircuitBreaker,
    CircuitState,
    CircuitBreakerOpenError,
)


class TestCircuitBreaker:
    """Test circuit breaker state transitions and behavior."""

    @pytest.mark.asyncio
    async def test_starts_closed(self):
        breaker = CircuitBreaker("test", failure_threshold=3, recovery_timeout=5)
        assert breaker.state == CircuitState.CLOSED

    @pytest.mark.asyncio
    async def test_opens_after_threshold_failures(self):
        breaker = CircuitBreaker("test", failure_threshold=3, recovery_timeout=60)

        @breaker
        async def failing_call():
            raise Exception("Service down")

        for _ in range(3):
            with pytest.raises(Exception, match="Service down"):
                await failing_call()

        assert breaker.state == CircuitState.OPEN

    @pytest.mark.asyncio
    async def test_blocks_calls_when_open(self):
        breaker = CircuitBreaker("test", failure_threshold=2, recovery_timeout=60)

        @breaker
        async def failing_call():
            raise Exception("down")

        # Trip the breaker
        for _ in range(2):
            with pytest.raises(Exception):
                await failing_call()

        # Now it should raise CircuitBreakerOpenError
        with pytest.raises(CircuitBreakerOpenError):
            await failing_call()

    @pytest.mark.asyncio
    async def test_success_resets_failure_count(self):
        breaker = CircuitBreaker("test", failure_threshold=3, recovery_timeout=60)
        call_count = 0

        @breaker
        async def sometimes_fails():
            nonlocal call_count
            call_count += 1
            if call_count <= 2:
                raise Exception("temporary failure")
            return "success"

        # 2 failures (below threshold)
        for _ in range(2):
            with pytest.raises(Exception):
                await sometimes_fails()

        # 1 success should reset
        result = await sometimes_fails()
        assert result == "success"
        assert breaker._failure_count == 0

    @pytest.mark.asyncio
    async def test_get_status(self):
        breaker = CircuitBreaker("TestService", failure_threshold=5, recovery_timeout=30)
        status = breaker.get_status()
        
        assert status["name"] == "TestService"
        assert status["state"] == "closed"
        assert status["failure_count"] == 0
        assert status["failure_threshold"] == 5
