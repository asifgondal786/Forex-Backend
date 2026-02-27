import asyncio

import pytest

from app.services.task_queue_service import TaskQueueService


@pytest.mark.asyncio
async def test_enqueue_returns_false_when_not_started():
    service = TaskQueueService()

    async def _noop():
        return None

    accepted = await service.enqueue("task:not-started", _noop)
    assert accepted is False


@pytest.mark.asyncio
async def test_queue_executes_enqueued_tasks():
    service = TaskQueueService()
    results = []

    async def _job(value):
        results.append(value)

    await service.start(workers=1, max_size=10)
    accepted = await service.enqueue("task:1", _job, "done")
    assert accepted is True

    await asyncio.sleep(0.05)
    stats = service.get_stats()
    await service.stop()

    assert results == ["done"]
    assert stats["enqueued"] == 1
    assert stats["completed"] == 1
    assert stats["failed"] == 0


@pytest.mark.asyncio
async def test_queue_reports_failed_task():
    service = TaskQueueService()

    async def _failing_job():
        raise RuntimeError("boom")

    await service.start(workers=1, max_size=10)
    accepted = await service.enqueue("task:fail", _failing_job)
    assert accepted is True

    await asyncio.sleep(0.05)
    stats = service.get_stats()
    await service.stop()

    assert stats["enqueued"] == 1
    assert stats["failed"] == 1
