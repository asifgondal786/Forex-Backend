"""
tasks_routes.py - /api/v1/tasks
"""
from fastapi import APIRouter, Depends, HTTPException
from .security import verify_http_request

router = APIRouter(prefix="/tasks", tags=["tasks"])


@router.get("/")
async def get_tasks(user=Depends(verify_http_request)):
    uid = getattr(user, "uid", None) or (user.get("uid") if isinstance(user, dict) else None)
    if not uid:
        raise HTTPException(status_code=401, detail="Unauthorized")
    return {
        "tasks": [],
        "user_id": uid,
        "message": "Tasks endpoint live."
    }


@router.get("/count")
async def get_task_count(user=Depends(verify_http_request)):
    uid = getattr(user, "uid", None) or (user.get("uid") if isinstance(user, dict) else None)
    if not uid:
        raise HTTPException(status_code=401, detail="Unauthorized")
    return {"count": 0, "user_id": uid}
