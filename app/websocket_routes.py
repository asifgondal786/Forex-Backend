"""
Complete WebSocket Routes with Live Forex Data Integration
"""
from fastapi import APIRouter, WebSocket, WebSocketDisconnect, HTTPException
from pydantic import BaseModel
from typing import Optional
import asyncio

from .enhanced_websocket_manager import ws_manager
from .forex_data_service import forex_service

router = APIRouter(prefix="/api", tags=["Live Updates"])


class UpdateRequest(BaseModel):
    task_id: str
    message: str
    type: str = "info"
    progress: Optional[float] = None


# ============================================================================
# WebSocket Endpoint
# ============================================================================

@router.websocket("/ws/{task_id}")
async def websocket_endpoint(websocket: WebSocket, task_id: str):
    """
    WebSocket endpoint for real-time updates for a specific task.

    Connect to: ws://localhost:8080/api/ws/{task_id}
    """
    await ws_manager.connect(websocket, task_id)
    try:
        while True:
            data = await websocket.receive_text()
            if data == "ping":
                await websocket.send_text("pong")
            else:
                await ws_manager.send_update(
                    task_id=task_id,
                    message=f"Received: {data}",
                    update_type="info",
                    websocket=websocket
                )
    except WebSocketDisconnect:
        ws_manager.disconnect(websocket, task_id)
    except Exception as e:
        print(f"WebSocket error for task {task_id}: {e}")
        ws_manager.disconnect(websocket, task_id)


@router.websocket("/ws")
async def websocket_global(websocket: WebSocket):
    """
    Global WebSocket endpoint for broadcasts.

    Connect to: ws://localhost:8080/api/ws
    """
    await ws_manager.connect(websocket, "global")
    try:
        while True:
            data = await websocket.receive_text()
            if data == "ping":
                await websocket.send_text("pong")
    except WebSocketDisconnect:
        ws_manager.disconnect(websocket, "global")
    except Exception as e:
        print(f"Global WebSocket error: {e}")
        ws_manager.disconnect(websocket, "global")


# ============================================================================
# HTTP Endpoints for Updates
# ============================================================================

@router.post("/updates/send")
async def send_update(update: UpdateRequest):
    """Send an update to connected clients via HTTP."""
    await ws_manager.send_update(
        task_id=update.task_id,
        message=update.message,
        update_type=update.type,
        progress=update.progress
    )
    return {"status": "success", "message": "Update sent", "task_id": update.task_id}


@router.get("/updates/connections")
async def get_all_connections():
    """Get total number of active WebSocket connections."""
    return {
        "total_connections": ws_manager.get_connection_count(),
        "tasks": list(ws_manager.active_connections.keys())
    }


# ============================================================================
# Forex Data Endpoints
# ============================================================================

@router.post("/forex/stream/start")
async def start_forex_stream(interval: int = 10):
    """Start streaming live forex data to all connected clients."""
    await ws_manager.start_forex_stream(interval)
    return {"status": "success", "message": f"Forex stream started with {interval}s interval."}


@router.post("/forex/stream/stop")
async def stop_forex_stream():
    """Stop the forex data stream."""
    ws_manager.stop_forex_stream()
    return {"status": "success", "message": "Forex stream stopped"}


@router.get("/forex/rates")
async def get_forex_rates():
    """Get current forex exchange rates."""
    try:
        await forex_service.initialize()
        rates = await forex_service.get_currency_rates()
        return {"status": "success", "rates": rates}
    finally:
        await forex_service.close()


@router.get("/forex/news")
async def get_forex_news():
    """Get latest forex news and economic calendar."""
    try:
        await forex_service.initialize()
        news = await forex_service.get_forex_factory_news()
        return {"status": "success", "news": news}
    finally:
        await forex_service.close()


@router.get("/forex/sentiment")
async def get_market_sentiment():
    """Get current market sentiment analysis."""
    try:
        await forex_service.initialize()
        sentiment = await forex_service.get_market_sentiment()
        return {"status": "success", "sentiment": sentiment}
    finally:
        await forex_service.close()


# ============================================================================
# Task Simulation Endpoints
# ============================================================================

@router.post("/tasks/simulate/{task_id}")
async def simulate_task(task_id: str):
    """Simulate a long-running task with live updates."""
    async def run_simulation():
        steps = [
            ("Initializing", 0.1, "Setting up task environment..."),
            ("Fetching Data", 0.3, "Retrieving forex market data..."),
            ("Analyzing", 0.6, "Running technical analysis..."),
            ("Generating Report", 0.9, "Creating summary report..."),
        ]

        for step_name, progress, message in steps:
            await ws_manager.send_task_progress(
                task_id=task_id,
                step=step_name,
                progress=progress,
                message=message
            )
            await asyncio.sleep(2)

        await ws_manager.send_task_complete(
            task_id=task_id,
            result={
                "summary": "Market analysis complete",
                "file_url": f"/downloads/{task_id}_report.pdf"
            }
        )

    # Start simulation in background
    asyncio.create_task(run_simulation())

    return {
        "status": "started",
        "task_id": task_id,
        "message": "Task simulation started. Connect to WebSocket for live updates."
    }