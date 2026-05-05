"""
conftest.py — Shared test fixtures for the Tajir backend test suite.
"""

import os
import pytest
import pytest_asyncio
from unittest.mock import AsyncMock, patch

# Force test mode
os.environ["TESTING"] = "true"
os.environ["REDIS_URL"] = "redis://localhost:6379/1"  # Use DB 1 for tests


@pytest.fixture
def mock_redis():
    """Mock Redis for tests that don't need a real connection."""
    with patch("app.services.redis_store.get_redis") as mock:
        redis_mock = AsyncMock()
        redis_mock.get.return_value = None
        redis_mock.set.return_value = True
        redis_mock.delete.return_value = True
        mock.return_value = redis_mock
        yield redis_mock


@pytest.fixture
def mock_firestore():
    """Mock Firestore for unit tests."""
    with patch("app.database.get_firestore_client") as mock:
        yield mock


@pytest.fixture
def sample_trade_request():
    """Standard trade request payload for testing."""
    return {
        "pair": "EUR/USD",
        "direction": "buy",
        "lot_size": 0.01,
        "stop_loss": 1.0850,
        "take_profit": 1.0950,
        "idempotency_key": "test-key-12345",
    }


@pytest.fixture
def sample_user():
    """Mock authenticated user."""
    return {
        "uid": "test-user-001",
        "email": "trader@tajir.app",
        "subscription_tier": "pro",
        "account_balance": 10000.0,
    }
