"""
AI Task Processing Routes
Handles "Assign New Task" functionality with full AI capabilities
"""
<<<<<<< HEAD
from fastapi import APIRouter, HTTPException, BackgroundTasks, Depends
from pydantic import BaseModel, Field, ConfigDict
from typing import Optional, List, Dict
from datetime import datetime, timezone
=======
from fastapi import APIRouter, HTTPException, BackgroundTasks
from pydantic import BaseModel
from typing import Optional, List, Dict
from datetime import datetime
>>>>>>> 6ea3e47c (AI task button files)
import uuid
import asyncio

from .ai_forex_engine import ai_engine
from .enhanced_websocket_manager import ws_manager
<<<<<<< HEAD
from .security import get_current_user_id
from .services.task_service import TaskService

router = APIRouter(prefix="/api/tasks", tags=["AI Tasks"])

_task_service = None


_activity_logger = None

async def _log_activity(user_id: str, message: str, activity_type: str = "monitor", emoji: str = None, color: str = None):
    if not user_id:
        return
    global _activity_logger
    try:
        if _activity_logger is None:
            from .services.engagement_activity_service import EngagementActivityService
            _activity_logger = EngagementActivityService()
        await asyncio.to_thread(
            _activity_logger.log_activity,
            user_id,
            activity_type,
            message,
            emoji,
            color,
        )
    except Exception as exc:
        print(f"Activity log failed: {exc}")


def _get_task_service() -> TaskService:
    global _task_service
    if _task_service is None:
        _task_service = TaskService()
    return _task_service


def _now() -> datetime:
    return datetime.now(timezone.utc)


def _serialize_datetime(value):
    if value is None:
        return None
    if hasattr(value, "to_datetime"):
        value = value.to_datetime()
    if isinstance(value, datetime):
        return value.isoformat()
    return str(value)


def _normalize_steps(steps: List[Dict]) -> List[Dict]:
    normalized = []
    for step in steps or []:
        if not isinstance(step, dict):
            continue
        completed_at = step.get("completedAt") or step.get("completed_at")
        normalized.append(
            {
                "name": step.get("name", ""),
                "isCompleted": bool(step.get("isCompleted") or step.get("is_completed")),
                "completedAt": _serialize_datetime(completed_at) if completed_at else None,
            }
        )
    return normalized


def _normalize_task(task_id: str, data: Dict) -> Dict:
    return {
        "id": task_id,
        "userId": data.get("userId") or data.get("user_id"),
        "title": data.get("title", ""),
        "description": data.get("description", ""),
        "status": data.get("status", "pending"),
        "priority": data.get("priority", "medium"),
        "createdAt": _serialize_datetime(data.get("createdAt") or data.get("created_at")),
        "startTime": _serialize_datetime(data.get("startTime") or data.get("start_time")),
        "endTime": _serialize_datetime(data.get("endTime") or data.get("end_time")),
        "currentStep": int(data.get("currentStep") or 0),
        "totalSteps": int(data.get("totalSteps") or 0),
        "steps": _normalize_steps(data.get("steps") or []),
        "resultFileUrl": data.get("resultFileUrl"),
        "resultFileName": data.get("resultFileName"),
        "resultFileSize": data.get("resultFileSize"),
    }


async def _get_task_raw(task_id: str) -> Optional[Dict]:
    service = _get_task_service()
    return await asyncio.to_thread(service.get_task, task_id)


async def _get_task(task_id: str) -> Optional[Dict]:
    data = await _get_task_raw(task_id)
    if not data:
        return None
    return _normalize_task(task_id, data)


async def _update_task(task_id: str, fetch: bool = False, **updates):
    service = _get_task_service()
    await asyncio.to_thread(service.update_task, task_id, updates)
    if fetch:
        return await _get_task(task_id)
    return None


async def _complete_step(task_id: str, step_name: str):
    service = _get_task_service()
    data = await asyncio.to_thread(service.get_task, task_id)
    if not data:
        return
    steps = list(data.get("steps") or [])
    updated = False
    completed_count = 0
    for step in steps:
        if not isinstance(step, dict):
            continue
        if step.get("name") == step_name and not step.get("isCompleted"):
            step["isCompleted"] = True
            step["completedAt"] = _now()
            updated = True
        if step.get("isCompleted"):
            completed_count += 1
    if not updated:
        return
    await asyncio.to_thread(
        service.update_task,
        task_id,
        {"steps": steps, "currentStep": completed_count},
    )


async def _require_task_owner(task_id: str, user_id: str) -> Dict:
    data = await _get_task_raw(task_id)
    if not data:
        raise HTTPException(status_code=404, detail="Task not found")
    if data.get("userId") != user_id:
        raise HTTPException(status_code=403, detail="Forbidden")
    return data

=======

router = APIRouter(prefix="/api/tasks", tags=["AI Tasks"])

>>>>>>> 6ea3e47c (AI task button files)

# ============================================================================
# REQUEST/RESPONSE MODELS
# ============================================================================

class TaskCreateRequest(BaseModel):
<<<<<<< HEAD
    model_config = ConfigDict(populate_by_name=True)

    user_id: Optional[str] = Field(default=None, alias="userId")
=======
>>>>>>> 6ea3e47c (AI task button files)
    title: str
    description: str
    task_type: str  # "market_analysis", "auto_trade", "forecast", "portfolio_monitor"
    priority: str = "medium"  # low, medium, high
    
    # Trading parameters
    currency_pairs: Optional[List[str]] = ["EUR/USD", "GBP/USD", "USD/JPY"]
    auto_trade_enabled: bool = False
    user_limits: Optional[Dict] = None  # max_loss, take_profit, etc.
    
    # Analysis parameters
    analysis_period_hours: int = 24
    include_forecast: bool = True
    forecast_horizon_hours: int = 24


class TaskResponse(BaseModel):
    id: str
    title: str
    description: str
    status: str
    priority: str
<<<<<<< HEAD
    createdAt: str
    startTime: Optional[str]
    currentStep: int
    totalSteps: int
    steps: List[Dict]
    resultFileUrl: Optional[str]
    
    class Config:
        populate_by_name = True  # Allow snake_case or camelCase from JSON
=======
    created_at: str
    start_time: Optional[str]
    current_step: int
    total_steps: int
    steps: List[Dict]
    result_file_url: Optional[str]
>>>>>>> 6ea3e47c (AI task button files)


# ============================================================================
# TASK EXECUTION ENGINE
# ============================================================================

async def execute_market_analysis_task(task_id: str, params: TaskCreateRequest):
    """
    Execute comprehensive market analysis task
    Steps: Fetch Data → Analyze Trends → Generate Report
    """
    
    try:
<<<<<<< HEAD
        await _update_task(task_id, status="running", startTime=_now())
=======
>>>>>>> 6ea3e47c (AI task button files)
        # Step 1: Fetch live market data
        await ws_manager.send_task_progress(
            task_id=task_id,
            step="Fetching Data",
            progress=0.2,
            message="Collecting live forex rates and economic calendar..."
        )
        
        await ai_engine.initialize()
        rates = await ai_engine.fetch_live_rates()
        calendar = await ai_engine.fetch_economic_calendar()
<<<<<<< HEAD
        await _complete_step(task_id, "Fetch Data")
=======
>>>>>>> 6ea3e47c (AI task button files)
        
        # Step 2: Analyze each currency pair
        await ws_manager.send_task_progress(
            task_id=task_id,
            step="Analyzing Markets",
            progress=0.4,
            message=f"Analyzing {len(params.currency_pairs)} currency pairs..."
        )
        
        analysis_results = {}
        
        for pair in params.currency_pairs:
            # Simulate historical prices (in production, fetch from API)
            historical_prices = [rates.get(pair, 1.0) * (1 + (i/1000 - 0.05)) 
                                for i in range(100)]
            
            # Analyze market conditions
            market_condition = await ai_engine.analyze_market_conditions(
                pair, historical_prices
            )
            
            # Generate trading signal
            signal = await ai_engine.generate_trading_signal(
                pair, 
                market_condition,
                params.user_limits or {}
            )
            
            # Forecast if requested
            forecast = None
            if params.include_forecast:
                forecast = await ai_engine.forecast_price_movement(
                    pair,
                    historical_prices,
                    params.forecast_horizon_hours
                )
            
            analysis_results[pair] = {
                "current_price": market_condition.current_price,
                "trend": market_condition.trend,
                "rsi": market_condition.rsi,
                "volatility": market_condition.volatility,
                "signal": {
                    "action": signal.action,
                    "confidence": signal.confidence,
                    "reason": signal.reason,
                    "entry_price": signal.entry_price,
                    "stop_loss": signal.stop_loss,
                    "take_profit": signal.take_profit
                },
                "forecast": forecast
            }
            
            # Send update for this pair
            await ws_manager.send_update(
                task_id=task_id,
                message=f"✅ Analyzed {pair}: {signal.action} signal with {signal.confidence:.0%} confidence",
                update_type="info",
<<<<<<< HEAD
                data=analysis_results[pair],
                user_id=params.user_id
            )
        
        await _complete_step(task_id, "Analyze Markets")
        await _complete_step(task_id, "Generate Signals")

=======
                data=analysis_results[pair]
            )
        
>>>>>>> 6ea3e47c (AI task button files)
        # Step 3: Generate comprehensive report
        await ws_manager.send_task_progress(
            task_id=task_id,
            step="Generating Report",
            progress=0.8,
            message="Creating detailed market analysis report..."
        )
        
        await asyncio.sleep(2)  # Simulate report generation
<<<<<<< HEAD
        await _complete_step(task_id, "Create Report")
=======
>>>>>>> 6ea3e47c (AI task button files)
        
        # Step 4: Complete
        await ws_manager.send_task_complete(
            task_id=task_id,
<<<<<<< HEAD
            user_id=params.user_id,
=======
>>>>>>> 6ea3e47c (AI task button files)
            result={
                "summary": f"Analysis complete for {len(params.currency_pairs)} pairs",
                "file_url": f"/downloads/{task_id}_market_analysis.pdf",
                "analysis": analysis_results,
                "economic_calendar": calendar,
                "timestamp": datetime.now().isoformat()
            }
        )
<<<<<<< HEAD
        await _update_task(
            task_id,
            status="completed",
            endTime=_now(),
            resultFileUrl=f"/downloads/{task_id}_market_analysis.pdf"
        )
        await _log_activity(
            user_id=params.user_id,
            message=f"Task completed: {params.title}",
            activity_type="decision",
        )
        
    except Exception as e:
        await ws_manager.send_error(task_id, str(e), user_id=params.user_id)
        await _update_task(task_id, status="failed", endTime=_now())
=======
        
    except Exception as e:
        await ws_manager.send_error(task_id, str(e))
>>>>>>> 6ea3e47c (AI task button files)
    finally:
        await ai_engine.close()


async def execute_auto_trading_task(task_id: str, params: TaskCreateRequest):
    """
    Execute automated trading task
    Monitors markets 24/7 and executes trades based on AI signals
    """
    
    try:
<<<<<<< HEAD
        await _update_task(task_id, status="running", startTime=_now())
=======
>>>>>>> 6ea3e47c (AI task button files)
        await ai_engine.initialize()
        
        await ws_manager.send_task_progress(
            task_id=task_id,
            step="Initializing",
            progress=0.1,
            message="Setting up autonomous trading engine..."
        )
<<<<<<< HEAD
        await _complete_step(task_id, "Initialize Engine")
=======
>>>>>>> 6ea3e47c (AI task button files)
        
        # Validate user limits
        if not params.user_limits:
            raise ValueError("Trading limits required for auto-trading")
        
        await ws_manager.send_task_progress(
            task_id=task_id,
            step="Monitoring Markets",
            progress=0.3,
            message=f"AI is now monitoring {len(params.currency_pairs)} pairs 24/7..."
        )
<<<<<<< HEAD
        await _complete_step(task_id, "Monitor Markets")
=======
>>>>>>> 6ea3e47c (AI task button files)
        
        # Continuous monitoring loop (simplified for demo)
        for i in range(5):  # In production, this runs indefinitely
            # Fetch current rates
            rates = await ai_engine.fetch_live_rates()
            
            # Check each pair for trading opportunities
            for pair in params.currency_pairs:
                if pair not in rates:
                    continue
                
                # Simulate historical data
                historical_prices = [rates[pair] * (1 + (j/1000 - 0.05)) 
                                    for j in range(100)]
                
                # Analyze and generate signal
                market_condition = await ai_engine.analyze_market_conditions(
                    pair, historical_prices
                )
                
                signal = await ai_engine.generate_trading_signal(
                    pair,
                    market_condition,
                    params.user_limits
                )
                
                # Execute trade if signal is strong
                if signal.action in ["BUY", "SELL"] and signal.confidence > 0.7:
                    trade_result = await ai_engine.execute_auto_trade(
                        signal,
                        params.user_limits
                    )
                    
                    if trade_result["executed"]:
                        await ws_manager.send_update(
                            task_id=task_id,
                            message=f"🤖 AUTO-TRADE: {signal.action} {pair} at {signal.entry_price:.4f}",
                            update_type="success",
<<<<<<< HEAD
                            data=trade_result,
                            user_id=params.user_id
                        )
                        await _complete_step(task_id, "Execute Trades")
=======
                            data=trade_result
                        )
>>>>>>> 6ea3e47c (AI task button files)
            
            # Monitor open positions
            closed_trades = await ai_engine.monitor_positions(rates)
            
            for trade in closed_trades:
                profit_emoji = "💰" if trade["profit"] > 0 else "📉"
                await ws_manager.send_update(
                    task_id=task_id,
                    message=f"{profit_emoji} Position closed: {trade['pair']} | Profit: ${trade['profit']:.2f}",
                    update_type="success" if trade["profit"] > 0 else "warning",
<<<<<<< HEAD
                    data=trade,
                    user_id=params.user_id
                )
                await _complete_step(task_id, "Manage Positions")
=======
                    data=trade
                )
>>>>>>> 6ea3e47c (AI task button files)
            
            # Update progress
            await ws_manager.send_task_progress(
                task_id=task_id,
                step="Active Trading",
                progress=0.3 + (i * 0.1),
                message=f"Active positions: {len(ai_engine.active_positions)} | Monitoring continues..."
            )
            
            await asyncio.sleep(10)  # Check every 10 seconds
        
        # Task completion
        await ws_manager.send_task_complete(
            task_id=task_id,
<<<<<<< HEAD
            user_id=params.user_id,
=======
>>>>>>> 6ea3e47c (AI task button files)
            result={
                "summary": "Auto-trading session completed",
                "trades_executed": 5,
                "total_profit": 150.50,
                "file_url": f"/downloads/{task_id}_trading_report.pdf"
            }
        )
<<<<<<< HEAD
        await _update_task(
            task_id,
            status="completed",
            endTime=_now(),
            resultFileUrl=f"/downloads/{task_id}_trading_report.pdf"
        )
        await _log_activity(
            user_id=params.user_id,
            message=f"Task completed: {params.title}",
            activity_type="decision",
        )
        
    except Exception as e:
        await ws_manager.send_error(task_id, str(e), user_id=params.user_id)
        await _update_task(task_id, status="failed", endTime=_now())
=======
        
    except Exception as e:
        await ws_manager.send_error(task_id, str(e))
>>>>>>> 6ea3e47c (AI task button files)
    finally:
        await ai_engine.close()


async def execute_forecast_task(task_id: str, params: TaskCreateRequest):
    """
    Execute price forecasting task
    Predicts future price movements using AI
    """
    
    try:
<<<<<<< HEAD
        await _update_task(task_id, status="running", startTime=_now())
=======
>>>>>>> 6ea3e47c (AI task button files)
        await ai_engine.initialize()
        
        await ws_manager.send_task_progress(
            task_id=task_id,
            step="Collecting Data",
            progress=0.2,
            message="Gathering historical price data..."
        )
        
        rates = await ai_engine.fetch_live_rates()
<<<<<<< HEAD
        await _complete_step(task_id, "Collect Historical Data")
=======
>>>>>>> 6ea3e47c (AI task button files)
        forecasts = {}
        
        await ws_manager.send_task_progress(
            task_id=task_id,
            step="Generating Forecasts",
            progress=0.5,
            message="AI is analyzing patterns and predicting future movements..."
        )
<<<<<<< HEAD
        await _complete_step(task_id, "Train AI Model")
=======
>>>>>>> 6ea3e47c (AI task button files)
        
        for pair in params.currency_pairs:
            # Simulate historical prices
            historical_prices = [rates.get(pair, 1.0) * (1 + (i/1000 - 0.05)) 
                                for i in range(100)]
            
            # Generate forecast
            forecast = await ai_engine.forecast_price_movement(
                pair,
                historical_prices,
                params.forecast_horizon_hours
            )
            
            forecasts[pair] = forecast
            
            await ws_manager.send_update(
                task_id=task_id,
                message=f"📊 {pair}: Predicted {forecast['expected_change_percent']:+.2f}% change in next {params.forecast_horizon_hours}h",
                update_type="info",
<<<<<<< HEAD
                data=forecast,
                user_id=params.user_id
            )
        
        await _complete_step(task_id, "Generate Predictions")

        await ws_manager.send_task_complete(
            task_id=task_id,
            user_id=params.user_id,
=======
                data=forecast
            )
        
        await ws_manager.send_task_complete(
            task_id=task_id,
>>>>>>> 6ea3e47c (AI task button files)
            result={
                "summary": f"Forecasts generated for {len(params.currency_pairs)} pairs",
                "forecasts": forecasts,
                "file_url": f"/downloads/{task_id}_forecasts.pdf"
            }
        )
<<<<<<< HEAD
        await _complete_step(task_id, "Create Forecast Report")
        await _update_task(
            task_id,
            status="completed",
            endTime=_now(),
            resultFileUrl=f"/downloads/{task_id}_forecasts.pdf"
        )
        await _log_activity(
            user_id=params.user_id,
            message=f"Task completed: {params.title}",
            activity_type="decision",
        )
        
    except Exception as e:
        await ws_manager.send_error(task_id, str(e), user_id=params.user_id)
        await _update_task(task_id, status="failed", endTime=_now())
=======
        
    except Exception as e:
        await ws_manager.send_error(task_id, str(e))
>>>>>>> 6ea3e47c (AI task button files)
    finally:
        await ai_engine.close()


# ============================================================================
# API ENDPOINTS
# ============================================================================

@router.post("/create", response_model=TaskResponse)
async def create_task(
    task: TaskCreateRequest,
<<<<<<< HEAD
    background_tasks: BackgroundTasks,
    user_id: str = Depends(get_current_user_id),
=======
    background_tasks: BackgroundTasks
>>>>>>> 6ea3e47c (AI task button files)
):
    """
    Create and execute an AI-powered forex task
    
    Task Types:
    - market_analysis: Comprehensive market analysis with signals
    - auto_trade: Autonomous 24/7 trading with user-defined limits
    - forecast: AI price prediction and trend analysis
    - portfolio_monitor: Real-time portfolio tracking and alerts
    """
    
    task_id = str(uuid.uuid4())
<<<<<<< HEAD
    task = task.model_copy(update={"user_id": user_id})
    await _log_activity(
        user_id=user_id,
        message=f"Task created: {task.title}",
        activity_type="monitor",
    )
=======
>>>>>>> 6ea3e47c (AI task button files)
    
    # Define task steps based on type
    steps_map = {
        "market_analysis": [
            {"name": "Fetch Data", "isCompleted": False},
            {"name": "Analyze Markets", "isCompleted": False},
            {"name": "Generate Signals", "isCompleted": False},
            {"name": "Create Report", "isCompleted": False}
        ],
        "auto_trade": [
            {"name": "Initialize Engine", "isCompleted": False},
            {"name": "Monitor Markets", "isCompleted": False},
            {"name": "Execute Trades", "isCompleted": False},
            {"name": "Manage Positions", "isCompleted": False}
        ],
        "forecast": [
            {"name": "Collect Historical Data", "isCompleted": False},
            {"name": "Train AI Model", "isCompleted": False},
            {"name": "Generate Predictions", "isCompleted": False},
            {"name": "Create Forecast Report", "isCompleted": False}
        ]
    }
    
    steps = steps_map.get(task.task_type, steps_map["market_analysis"])
<<<<<<< HEAD

    now = _now()
    task_data = {
        "id": task_id,
        "userId": task.user_id,
        "title": task.title,
        "description": task.description,
        "status": "running",
        "priority": task.priority,
        "createdAt": now,
        "startTime": now,
        "endTime": None,
        "currentStep": 0,
        "totalSteps": len(steps),
        "steps": steps,
        "resultFileUrl": None,
        "resultFileName": None,
        "resultFileSize": None,
        "taskType": task.task_type,
    }

    service = _get_task_service()
    await asyncio.to_thread(service.create_task, task_id, task_data)
    task_response = TaskResponse(**_normalize_task(task_id, task_data))
=======
    
    # Create task response
    task_response = TaskResponse(
        id=task_id,
        title=task.title,
        description=task.description,
        status="running",
        priority=task.priority,
        created_at=datetime.now().isoformat(),
        start_time=datetime.now().isoformat(),
        current_step=0,
        total_steps=len(steps),
        steps=steps,
        result_file_url=None
    )
>>>>>>> 6ea3e47c (AI task button files)
    
    # Execute task in background based on type
    if task.task_type == "market_analysis":
        background_tasks.add_task(execute_market_analysis_task, task_id, task)
    elif task.task_type == "auto_trade":
        background_tasks.add_task(execute_auto_trading_task, task_id, task)
    elif task.task_type == "forecast":
        background_tasks.add_task(execute_forecast_task, task_id, task)
    
    return task_response


<<<<<<< HEAD
@router.get("/")
async def list_tasks(user_id: Optional[str] = None, current_user_id: str = Depends(get_current_user_id)):
    """List tasks (Firestore-backed)"""
    if user_id and user_id != current_user_id:
        raise HTTPException(status_code=403, detail="Forbidden")

    service = _get_task_service()
    raw_tasks = await asyncio.to_thread(service.list_tasks, current_user_id)

    def _sort_key(item):
        created = item[1].get("createdAt")
        if hasattr(created, "to_datetime"):
            created = created.to_datetime()
        if isinstance(created, datetime):
            return created
        return datetime.min.replace(tzinfo=timezone.utc)

    raw_tasks.sort(key=_sort_key, reverse=True)
    tasks = [_normalize_task(task_id, data) for task_id, data in raw_tasks]
    return {"tasks": tasks, "total": len(tasks)}


@router.get("/{task_id}")
async def get_task(task_id: str, current_user_id: str = Depends(get_current_user_id)):
    """Get task status and details"""
    task = await _get_task_raw(task_id)
    if not task:
        raise HTTPException(status_code=404, detail="Task not found")
    if task.get("userId") != current_user_id:
        raise HTTPException(status_code=403, detail="Forbidden")
    return _normalize_task(task_id, task)


@router.post("/{task_id}/stop")
async def stop_task(task_id: str, user_id: str = Depends(get_current_user_id)):
    """Stop a running task"""
    await _require_task_owner(task_id, user_id)
    await ws_manager.send_update(
        task_id=task_id,
        message="Task stopped by user",
        update_type="warning",
        user_id=user_id
    )
    updated = await _update_task(task_id, fetch=True, status="paused", endTime=_now())
    return updated or {"message": "Task stopped", "task_id": task_id}


@router.post("/{task_id}/pause")
async def pause_task(task_id: str, user_id: str = Depends(get_current_user_id)):
    """Pause a running task"""
    await _require_task_owner(task_id, user_id)
    await ws_manager.send_update(
        task_id=task_id,
        message="Task paused by user",
        update_type="warning",
        user_id=user_id
    )
    updated = await _update_task(task_id, fetch=True, status="paused")
    return updated or {"message": "Task paused", "task_id": task_id}


@router.post("/{task_id}/resume")
async def resume_task(task_id: str, user_id: str = Depends(get_current_user_id)):
    """Resume a paused task"""
    await _require_task_owner(task_id, user_id)
    await ws_manager.send_update(
        task_id=task_id,
        message="Task resumed by user",
        update_type="info",
        user_id=user_id
    )
    updated = await _update_task(task_id, fetch=True, status="running")
    return updated or {"message": "Task resumed", "task_id": task_id}


@router.delete("/{task_id}")
async def delete_task(task_id: str, user_id: str = Depends(get_current_user_id)):
    """Delete a task"""
    await _require_task_owner(task_id, user_id)
    service = _get_task_service()
    await asyncio.to_thread(service.delete_task, task_id)
    return {"message": "Task deleted", "id": task_id}
=======
@router.get("/{task_id}")
async def get_task(task_id: str):
    """Get task status and details"""
    # In production, fetch from database
    return {
        "id": task_id,
        "status": "running",
        "message": "Task is executing. Connect to WebSocket for live updates."
    }


@router.post("/{task_id}/stop")
async def stop_task(task_id: str):
    """Stop a running task"""
    await ws_manager.send_update(
        task_id=task_id,
        message="Task stopped by user",
        update_type="warning"
    )
    
    return {"message": "Task stopped", "task_id": task_id}
>>>>>>> 6ea3e47c (AI task button files)


@router.get("/market/live-rates")
async def get_live_rates():
    """Get current forex rates"""
    await ai_engine.initialize()
    rates = await ai_engine.fetch_live_rates()
    await ai_engine.close()
    
    return {
        "timestamp": datetime.now().isoformat(),
        "rates": rates
    }


@router.get("/market/economic-calendar")
async def get_economic_calendar():
    """Get upcoming economic events"""
    await ai_engine.initialize()
    calendar = await ai_engine.fetch_economic_calendar()
    await ai_engine.close()
    
    return {
        "events": calendar
<<<<<<< HEAD
    }
=======
    }
>>>>>>> 6ea3e47c (AI task button files)
