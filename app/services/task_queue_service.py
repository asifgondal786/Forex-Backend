"""Async task queue with optional Redis backend for scaling."""

from __future__ import annotations

import asyncio
import json
import os
import uuid
from dataclasses import dataclass, field
from datetime import datetime, timezone
from typing import Any, Awaitable, Callable, Dict, Optional

from .redis_store import redis_store


@dataclass
class QueuedTask:
    task_key: str
    coroutine: Callable[..., Awaitable[Any]]
    args: tuple[Any, ...] = field(default_factory=tuple)
    kwargs: Dict[str, Any] = field(default_factory=dict)
    enqueued_at: str = field(default_factory=lambda: datetime.now(timezone.utc).isoformat())


class TaskQueueService:
    """Async task queue with in-memory and Redis-backed modes."""

    def __init__(self):
        self._queue: Optional[asyncio.Queue[Optional[QueuedTask]]] = None
        self._workers: list[asyncio.Task] = []
        self._worker_count = 0
        self._max_size = 0
        self._started = False
        self._backend_requested = "memory"
        self._backend_active = "memory"
        self._registered_handlers: Dict[str, Callable[..., Awaitable[Any]]] = {}
        self._enqueued = 0
        self._completed = 0
        self._failed = 0
        self._redis_queue_key = "forex:task_queue"
        self._redis_block_seconds = 1
        self._redis_queue_size_estimate = 0

    def register_handler(self, name: str, coroutine: Callable[..., Awaitable[Any]]) -> None:
        key = (name or "").strip()
        if not key:
            return
        self._registered_handlers[key] = coroutine

    def _resolve_handler_name(
        self,
        coroutine: Callable[..., Awaitable[Any]],
    ) -> Optional[str]:
        for name, handler in self._registered_handlers.items():
            if handler is coroutine:
                return name
        return None

    async def start(self, workers: int = 1, max_size: int = 200):
        if self._started:
            return

        self._backend_requested = (os.getenv("TASK_QUEUE_BACKEND", "memory") or "memory").strip().lower()
        self._backend_active = "memory"
        self._redis_queue_key = (os.getenv("TASK_QUEUE_REDIS_KEY") or "forex:task_queue").strip()
        if not self._redis_queue_key:
            self._redis_queue_key = "forex:task_queue"
        try:
            self._redis_block_seconds = max(1, int(os.getenv("TASK_QUEUE_REDIS_BLOCK_SECONDS", "1")))
        except Exception:
            self._redis_block_seconds = 1

        if self._backend_requested == "redis":
            if await redis_store.ensure_connected():
                self._backend_active = "redis"
                self._redis_queue_size_estimate = await redis_store.get_queue_length(
                    self._redis_queue_key
                )
            else:
                print("[TaskQueue] Redis backend unavailable; falling back to memory.")

        self._worker_count = max(1, int(workers))
        self._max_size = max(1, int(max_size))
        self._queue = (
            asyncio.Queue(maxsize=self._max_size)
            if self._backend_active == "memory"
            else None
        )
        self._workers = [
            asyncio.create_task(self._worker_loop(index), name=f"task-queue-worker-{index}")
            for index in range(self._worker_count)
        ]
        self._started = True
        print(
            f"[TaskQueue] Started backend={self._backend_active} "
            f"(requested={self._backend_requested}) workers={self._worker_count}, max_size={self._max_size}"
        )

    async def stop(self):
        if not self._started:
            return
        self._started = False
        if self._backend_active == "memory" and self._queue is not None:
            for _ in self._workers:
                await self._queue.put(None)

        await asyncio.gather(*self._workers, return_exceptions=True)
        self._workers.clear()
        self._queue = None
        if self._backend_active == "redis":
            self._redis_queue_size_estimate = await redis_store.get_queue_length(
                self._redis_queue_key
            )
        print("[TaskQueue] Stopped")

    async def enqueue(
        self,
        task_key: str,
        coroutine: Callable[..., Awaitable[Any]],
        *args: Any,
        **kwargs: Any,
    ) -> bool:
        if not self._started:
            return False

        if self._backend_active == "redis":
            handler_name = self._resolve_handler_name(coroutine)
            if not handler_name:
                print(
                    f"[TaskQueue] Redis mode requires registered handler for task: {task_key}"
                )
                return False
            try:
                json.dumps(args)
                json.dumps(kwargs)
            except TypeError:
                print(
                    f"[TaskQueue] Redis mode requires JSON-serializable args for task: {task_key}"
                )
                return False

            queue_item = {
                "job_id": str(uuid.uuid4()),
                "task_key": task_key,
                "handler": handler_name,
                "args": list(args),
                "kwargs": dict(kwargs),
                "enqueued_at": datetime.now(timezone.utc).isoformat(),
            }
            pushed = await redis_store.push_queue_item(self._redis_queue_key, queue_item)
            if not pushed:
                return False
            self._enqueued += 1
            self._redis_queue_size_estimate += 1
            return True

        if self._queue is None:
            return False

        item = QueuedTask(
            task_key=task_key,
            coroutine=coroutine,
            args=args,
            kwargs=kwargs,
        )
        try:
            self._queue.put_nowait(item)
        except asyncio.QueueFull:
            print(f"[TaskQueue] Queue full, rejected task: {task_key}")
            return False

        self._enqueued += 1
        return True

    def get_stats(self) -> Dict[str, Any]:
        queue_size = (
            self._queue.qsize()
            if self._backend_active == "memory" and self._queue is not None
            else max(0, int(self._redis_queue_size_estimate))
        )
        return {
            "started": self._started,
            "backend_requested": self._backend_requested,
            "backend": self._backend_active,
            "workers": self._worker_count,
            "max_size": self._max_size,
            "queue_size": queue_size,
            "enqueued": self._enqueued,
            "completed": self._completed,
            "failed": self._failed,
            "registered_handlers": sorted(self._registered_handlers.keys()),
            "redis_queue_key": self._redis_queue_key if self._backend_active == "redis" else None,
        }

    async def _worker_loop(self, worker_index: int):
        if self._backend_active == "redis":
            await self._redis_worker_loop(worker_index)
            return
        await self._memory_worker_loop(worker_index)

    async def _memory_worker_loop(self, worker_index: int):
        if self._queue is None:
            return
        while True:
            item = await self._queue.get()
            try:
                if item is None:
                    return
                await item.coroutine(*item.args, **item.kwargs)
                self._completed += 1
            except Exception as exc:
                self._failed += 1
                task_key = item.task_key if item else "unknown"
                print(f"[TaskQueue] Worker {worker_index} task '{task_key}' failed: {exc}")
            finally:
                self._queue.task_done()

    async def _redis_worker_loop(self, worker_index: int):
        while self._started:
            job = await redis_store.pop_queue_item(
                self._redis_queue_key,
                timeout_seconds=self._redis_block_seconds,
            )
            if not job:
                await asyncio.sleep(0)
                continue

            self._redis_queue_size_estimate = max(0, self._redis_queue_size_estimate - 1)
            task_key = str(job.get("task_key") or "unknown")
            handler_name = str(job.get("handler") or "")
            handler = self._registered_handlers.get(handler_name)
            if handler is None:
                self._failed += 1
                print(
                    f"[TaskQueue] Worker {worker_index} missing handler '{handler_name}' "
                    f"for task '{task_key}'"
                )
                continue

            args = job.get("args") or []
            kwargs = job.get("kwargs") or {}
            if not isinstance(args, list):
                args = [args]
            if not isinstance(kwargs, dict):
                kwargs = {}

            try:
                await handler(*args, **kwargs)
                self._completed += 1
            except Exception as exc:
                self._failed += 1
                print(f"[TaskQueue] Worker {worker_index} task '{task_key}' failed: {exc}")


task_queue_service = TaskQueueService()
