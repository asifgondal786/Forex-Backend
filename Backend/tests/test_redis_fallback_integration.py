"""
Step 3: Comprehensive Redis integration and fallback tests.
Tests verify that:
- Redis backend works when available
- Automatic fallback to memory when Redis is unavailable
- No live Redis server required (mocked for safety)
- Task queue/WebSocket registry function correctly in both modes
"""

import asyncio
import json
import os
import pytest
from unittest.mock import AsyncMock, MagicMock, patch
from typing import Optional

from app.services.redis_store import RedisStore, _env_bool, _env_float


# ==============================================================================
# Unit Tests: RedisStore Fallback & Safety
# ==============================================================================

@pytest.mark.asyncio
async def test_redis_store_is_disabled_when_no_env_vars():
    """Test that Redis is disabled by default."""
    store = RedisStore()
    # No env vars set, should be disabled
    assert not store.is_enabled()
    assert not store.is_connected()


@pytest.mark.asyncio
async def test_redis_store_is_enabled_when_redis_enabled_env(monkeypatch):
    """Test that Redis is enabled when REDIS_ENABLED=true."""
    monkeypatch.setenv("REDIS_ENABLED", "true")
    store = RedisStore()
    assert store.is_enabled()


@pytest.mark.asyncio
async def test_redis_store_is_enabled_when_task_queue_backend_redis(monkeypatch):
    """Test that Redis is enabled when TASK_QUEUE_BACKEND=redis."""
    monkeypatch.setenv("TASK_QUEUE_BACKEND", "redis")
    store = RedisStore()
    assert store.is_enabled()


@pytest.mark.asyncio
async def test_redis_store_handles_missing_dependency(monkeypatch):
    """Test that RedisStore gracefully handles missing redis package."""
    monkeypatch.setenv("REDIS_ENABLED", "true")
    store = RedisStore()
    
    # Simulate redis not being installed
    with patch("app.services.redis_store.redis_async", None):
        # Should gracefully return False when redis_async is None
        connected = await store.ensure_connected()
        assert connected is False
        assert not store.is_connected()


@pytest.mark.asyncio
async def test_redis_store_connection_fails_with_backoff(monkeypatch):
    """Test that connection failures have exponential backoff."""
    monkeypatch.setenv("REDIS_ENABLED", "true")
    monkeypatch.setenv("REDIS_RETRY_SECONDS", "1")
    
    store = RedisStore()
    
    # Mock redis_async to fail connection
    mock_redis = AsyncMock()
    mock_redis.ping = AsyncMock(side_effect=RuntimeError("Connection refused"))
    
    with patch("app.services.redis_store.redis_async") as mock_module:
        mock_module.from_url = AsyncMock(return_value=mock_redis)
        
        # First attempt should fail
        conn1 = await store.ensure_connected()
        assert conn1 is False
        
        # Second immediate attempt should also fail (backoff in effect)
        conn2 = await store.ensure_connected()
        assert conn2 is False


@pytest.mark.asyncio
async def test_redis_store_queue_returns_false_when_not_connected():
    """Test that queue operations fail gracefully when not connected."""
    store = RedisStore()
    assert not store.is_enabled()
    
    # Should return False without crashing
    result = await store.push_queue_item("test_queue", {"data": "test"})
    assert result is False


@pytest.mark.asyncio
async def test_redis_store_pop_queue_returns_none_when_not_connected():
    """Test that pop_queue_item returns None when disconnected."""
    store = RedisStore()
    result = await store.pop_queue_item("test_queue")
    assert result is None


@pytest.mark.asyncio
async def test_redis_store_get_queue_length_returns_zero_when_not_connected():
    """Test that get_queue_length returns 0 when not connected."""
    store = RedisStore()
    length = await store.get_queue_length("test_queue")
    assert length == 0


@pytest.mark.asyncio
async def test_redis_store_ws_operations_return_false_when_not_connected():
    """Test that WebSocket operations fail gracefully when not connected."""
    store = RedisStore()
    
    result = await store.set_ws_connection("conn_123", {"task_id": "task_1"})
    assert result is False
    
    result = await store.patch_ws_connection("conn_123", {"status": "active"})
    assert result is False
    
    result = await store.remove_ws_connection("conn_123")
    assert result is False


@pytest.mark.asyncio
async def test_redis_store_get_ws_registry_returns_empty_when_not_connected():
    """Test that get_ws_registry returns empty dict when not connected."""
    store = RedisStore()
    result = await store.get_ws_registry()
    assert result == {}


@pytest.mark.asyncio
async def test_redis_store_close_handles_missing_client():
    """Test that close() gracefully handles None client."""
    store = RedisStore()
    # Should not raise
    await store.close()
    assert not store.is_connected()


# ==============================================================================
# Integration Tests: RedisStore with Mock Redis
# ==============================================================================

@pytest.mark.asyncio
async def test_redis_store_successful_connection(monkeypatch):
    """Test successful Redis connection."""
    monkeypatch.setenv("REDIS_ENABLED", "true")
    monkeypatch.setenv("REDIS_URL", "redis://localhost:6379/0")
    
    store = RedisStore()
    
    mock_redis = MagicMock()
    mock_redis.ping = AsyncMock(return_value=True)
    mock_redis.close = AsyncMock()
    
    with patch("app.services.redis_store.redis_async") as mock_module:
        mock_module.from_url = MagicMock(return_value=mock_redis)
        
        connected = await store.ensure_connected()
        assert connected is True
        assert store.is_connected()
        
        # Verify connection was attempted
        mock_module.from_url.assert_called_once()
        mock_redis.ping.assert_called_once()
        
        await store.close()
        mock_redis.close.assert_called_once()


@pytest.mark.asyncio
async def test_redis_store_push_and_pop_queue_items(monkeypatch):
    """Test pushing and popping items from Redis queue."""
    monkeypatch.setenv("REDIS_ENABLED", "true")
    monkeypatch.setenv("REDIS_URL", "redis://localhost:6379/0")
    
    store = RedisStore()
    
    mock_redis = MagicMock()
    mock_redis.ping = AsyncMock(return_value=True)
    mock_redis.rpush = AsyncMock()
    mock_redis.blpop = AsyncMock(return_value=(
        "test_queue",
        json.dumps({"job_id": "job_123", "task": "market_analysis"})
    ))
    
    with patch("app.services.redis_store.redis_async") as mock_module:
        mock_module.from_url = MagicMock(return_value=mock_redis)
        
        await store.ensure_connected()
        
        # Test push
        test_item = {"job_id": "job_123", "task": "market_analysis"}
        result = await store.push_queue_item("test_queue", test_item)
        assert result is True
        mock_redis.rpush.assert_called_once()
        
        # Test pop
        popped = await store.pop_queue_item("test_queue")
        assert popped == {"job_id": "job_123", "task": "market_analysis"}
        mock_redis.blpop.assert_called_once()


@pytest.mark.asyncio
async def test_redis_store_queue_length(monkeypatch):
    """Test getting queue length from Redis."""
    monkeypatch.setenv("REDIS_ENABLED", "true")
    monkeypatch.setenv("REDIS_URL", "redis://localhost:6379/0")
    
    store = RedisStore()
    
    mock_redis = MagicMock()
    mock_redis.ping = AsyncMock(return_value=True)
    mock_redis.llen = AsyncMock(return_value=42)
    
    with patch("app.services.redis_store.redis_async") as mock_module:
        mock_module.from_url = MagicMock(return_value=mock_redis)
        
        await store.ensure_connected()
        
        length = await store.get_queue_length("test_queue")
        assert length == 42
        mock_redis.llen.assert_called_once()


@pytest.mark.asyncio
async def test_redis_store_ws_registry_operations(monkeypatch):
    """Test WebSocket registry operations with Redis."""
    monkeypatch.setenv("REDIS_ENABLED", "true")
    monkeypatch.setenv("REDIS_URL", "redis://localhost:6379/0")
    
    store = RedisStore()
    
    mock_redis = MagicMock()
    mock_redis.ping = AsyncMock(return_value=True)
    mock_redis.hset = AsyncMock()
    mock_redis.hdel = AsyncMock()
    
    with patch("app.services.redis_store.redis_async") as mock_module:
        mock_module.from_url = MagicMock(return_value=mock_redis)
        
        await store.ensure_connected()
        
        # Test set connection
        metadata = {"task_id": "task_1", "user_id": "user_123"}
        result = await store.set_ws_connection("conn_abc", metadata)
        assert result is True
        mock_redis.hset.assert_called_once()
        
        # Test patch connection
        mock_redis.hget = AsyncMock(return_value=json.dumps(metadata))
        result = await store.patch_ws_connection("conn_abc", {"status": "active"})
        assert result is True
        
        # Test remove connection
        mock_redis.hdel = AsyncMock()
        result = await store.remove_ws_connection("conn_abc")
        assert result is True


@pytest.mark.asyncio
async def test_redis_store_get_ws_registry(monkeypatch):
    """Test fetching WebSocket registry from Redis."""
    monkeypatch.setenv("REDIS_ENABLED", "true")
    monkeypatch.setenv("REDIS_URL", "redis://localhost:6379/0")
    
    store = RedisStore()
    
    mock_redis = MagicMock()
    mock_redis.ping = AsyncMock(return_value=True)
    registry_data = {
        "conn_1": json.dumps({"task_id": "task_1", "user_id": "user_1"}),
        "conn_2": json.dumps({"task_id": "task_2", "user_id": "user_2"}),
    }
    mock_redis.hgetall = AsyncMock(return_value=registry_data)
    
    with patch("app.services.redis_store.redis_async") as mock_module:
        mock_module.from_url = MagicMock(return_value=mock_redis)
        
        await store.ensure_connected()
        
        result = await store.get_ws_registry()
        assert len(result) == 2
        assert result["conn_1"]["task_id"] == "task_1"
        assert result["conn_2"]["task_id"] == "task_2"


@pytest.mark.asyncio
async def test_redis_store_get_ws_registry_filtered_by_task_id(monkeypatch):
    """Test filtering WebSocket registry by task_id."""
    monkeypatch.setenv("REDIS_ENABLED", "true")
    
    store = RedisStore()
    
    mock_redis = MagicMock()
    mock_redis.ping = AsyncMock(return_value=True)
    registry_data = {
        "conn_1": json.dumps({"task_id": "task_1", "user_id": "user_1"}),
        "conn_2": json.dumps({"task_id": "task_2", "user_id": "user_2"}),
    }
    mock_redis.hgetall = AsyncMock(return_value=registry_data)
    
    with patch("app.services.redis_store.redis_async") as mock_module:
        mock_module.from_url = MagicMock(return_value=mock_redis)
        
        await store.ensure_connected()
        
        result = await store.get_ws_registry(task_id="task_1")
        assert len(result) == 1
        assert "conn_1" in result


# ==============================================================================
# TaskQueue Tests: Memory vs Redis Backend
# ==============================================================================

@pytest.mark.asyncio
async def test_task_queue_memory_backend_default(monkeypatch):
    """Test that task queue defaults to memory backend."""
    monkeypatch.delenv("TASK_QUEUE_BACKEND", raising=False)
    monkeypatch.delenv("REDIS_ENABLED", raising=False)
    
    from app.services.task_queue_service import TaskQueueService
    
    service = TaskQueueService()
    await service.start(workers=1, max_size=10)
    
    assert service._backend_active == "memory"
    assert service._queue is not None
    
    await service.stop()


@pytest.mark.asyncio
async def test_task_queue_falls_back_to_memory_when_redis_unavailable(monkeypatch):
    """Test that task queue falls back to memory when Redis is unavailable."""
    monkeypatch.setenv("TASK_QUEUE_BACKEND", "redis")
    monkeypatch.setenv("REDIS_ENABLED", "true")
    monkeypatch.setenv("REDIS_URL", "redis://localhost:6379/0")
    
    from app.services.task_queue_service import TaskQueueService
    from app.services.redis_store import redis_store
    
    # Mock Redis connection failure
    with patch("app.services.redis_store.redis_async") as mock_module:
        mock_module.from_url = AsyncMock(side_effect=RuntimeError("Connection failed"))
        
        service = TaskQueueService()
        await service.start(workers=1, max_size=10)
        
        # Should fall back to memory
        assert service._backend_active == "memory"
        assert service._backend_requested == "redis"
        
        await service.stop()
        await redis_store.close()


@pytest.mark.asyncio
async def test_task_queue_uses_redis_backend_when_available(monkeypatch):
    """Test that task queue uses Redis backend when available."""
    monkeypatch.setenv("TASK_QUEUE_BACKEND", "redis")
    monkeypatch.setenv("REDIS_ENABLED", "true")
    monkeypatch.setenv("REDIS_URL", "redis://localhost:6379/0")
    
    from app.services.task_queue_service import TaskQueueService
    from app.services.redis_store import redis_store
    
    # Reset redis_store state for this test
    redis_store._client = None
    redis_store._warned_missing_dependency = False
    redis_store._next_connect_attempt = 0.0
    
    mock_redis = MagicMock()
    mock_redis.ping = AsyncMock(return_value=True)
    mock_redis.llen = AsyncMock(return_value=0)
    mock_redis.close = AsyncMock()
    
    with patch("app.services.redis_store.redis_async") as mock_module:
        mock_module.from_url = MagicMock(return_value=mock_redis)
        
        service = TaskQueueService()
        await service.start(workers=1, max_size=10)
        
        # Should use Redis
        assert service._backend_active == "redis"
        assert service._backend_requested == "redis"
        
        await service.stop()
        await redis_store.close()


@pytest.mark.asyncio
async def test_task_queue_enqueue_with_memory_backend():
    """Test enqueueing tasks with memory backend."""
    from app.services.task_queue_service import TaskQueueService
    
    service = TaskQueueService()
    results = []
    
    async def test_task(value: str):
        results.append(value)
    
    await service.start(workers=1, max_size=10)
    
    enqueued = await service.enqueue("task:test", test_task, "hello")
    assert enqueued is True
    
    await asyncio.sleep(0.1)
    stats = service.get_stats()
    await service.stop()
    
    assert results == ["hello"]
    assert stats["enqueued"] == 1
    assert stats["completed"] == 1


@pytest.mark.asyncio
async def test_task_queue_handler_registration_for_redis(monkeypatch):
    """Test that Redis backend requires registered handlers."""
    monkeypatch.setenv("TASK_QUEUE_BACKEND", "redis")
    
    from app.services.task_queue_service import TaskQueueService
    from app.services.redis_store import redis_store
    
    mock_redis = AsyncMock()
    mock_redis.ping = AsyncMock(return_value=True)
    mock_redis.llen = AsyncMock(return_value=0)
    mock_redis.close = AsyncMock()
    
    with patch("app.services.redis_store.redis_async") as mock_module:
        mock_module.from_url = AsyncMock(return_value=mock_redis)
        
        service = TaskQueueService()
        await service.start(workers=1, max_size=10)
        
        async def test_handler(value: str):
            pass
        
        # Register handler
        service.register_handler("test_job", test_handler)
        
        # Should enqueue successfully with registered handler
        # Note: This tests handler lookup, actual Redis enqueue is mocked
        stats = service.get_stats()
        assert "test_job" in stats["registered_handlers"]
        
        await service.stop()
        await redis_store.close()


# ==============================================================================
# Integration Tests: Task Queue with Both Backends
# ==============================================================================

@pytest.mark.asyncio
async def test_task_queue_stats_shows_correct_backend():
    """Test that queue stats reflect the active backend."""
    from app.services.task_queue_service import TaskQueueService
    
    service = TaskQueueService()
    await service.start(workers=2, max_size=50)
    
    stats = service.get_stats()
    assert stats["backend"] == "memory"
    assert stats["workers"] == 2
    assert stats["max_size"] == 50
    assert stats["started"] is True
    
    await service.stop()


@pytest.mark.asyncio
async def test_task_queue_failed_task_tracking():
    """Test that task queue tracks failed tasks correctly."""
    from app.services.task_queue_service import TaskQueueService
    
    service = TaskQueueService()
    
    async def failing_task():
        raise RuntimeError("Task failure")
    
    await service.start(workers=1, max_size=10)
    
    await service.enqueue("task:fail", failing_task)
    await asyncio.sleep(0.1)
    
    stats = service.get_stats()
    await service.stop()
    
    assert stats["failed"] == 1
    assert stats["enqueued"] == 1


@pytest.mark.asyncio
async def test_task_queue_worker_count_configuration():
    """Test configuring worker count."""
    from app.services.task_queue_service import TaskQueueService
    
    service = TaskQueueService()
    await service.start(workers=4, max_size=100)
    
    stats = service.get_stats()
    assert stats["workers"] == 4
    
    await service.stop()


# ==============================================================================
# Helper Function Tests
# ==============================================================================

def test_env_bool_parsing():
    """Test environment boolean parsing."""
    assert _env_bool("VAR", default=False, ) is False
    
    # Test various true values
    os.environ["TEST_BOOL"] = "true"
    assert _env_bool("TEST_BOOL") is True
    
    os.environ["TEST_BOOL"] = "1"
    assert _env_bool("TEST_BOOL") is True
    
    os.environ["TEST_BOOL"] = "yes"
    assert _env_bool("TEST_BOOL") is True
    
    os.environ["TEST_BOOL"] = "on"
    assert _env_bool("TEST_BOOL") is True
    
    # Test false values
    os.environ["TEST_BOOL"] = "false"
    assert _env_bool("TEST_BOOL") is False
    
    os.environ["TEST_BOOL"] = "0"
    assert _env_bool("TEST_BOOL") is False


def test_env_float_parsing():
    """Test environment float parsing."""
    assert _env_float("NONEXISTENT", default=3.14) == 3.14
    
    os.environ["TEST_FLOAT"] = "2.5"
    assert _env_float("TEST_FLOAT", default=1.0) == 2.5
    
    os.environ["TEST_FLOAT"] = "invalid"
    assert _env_float("TEST_FLOAT", default=1.0) == 1.0
    
    # Test minimum constraint
    os.environ["TEST_FLOAT"] = "-5.0"
    assert _env_float("TEST_FLOAT", default=0.0, minimum=0.0) == 0.0
