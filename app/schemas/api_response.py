from __future__ import annotations

from typing import Any, Dict, Optional, Literal

from pydantic import BaseModel, ConfigDict, Field


class APIResponse(BaseModel):
    model_config = ConfigDict(populate_by_name=True)

    status: Literal["success", "error"]
    message: str
    data: Optional[Dict[str, Any]] = None
    request_id: Optional[str] = Field(default=None, alias="requestId")


def normalize_data(payload: Any) -> Optional[Dict[str, Any]]:
    if payload is None:
        return None
    if isinstance(payload, dict):
        return payload
    if isinstance(payload, list):
        return {"items": payload}
    return {"value": payload}


def is_api_response_payload(payload: Any) -> bool:
    if not isinstance(payload, dict):
        return False
    return {"status", "message", "data"}.issubset(set(payload.keys()))


def success_payload(
    *,
    data: Any = None,
    message: str = "OK",
    request_id: Optional[str] = None,
) -> Dict[str, Any]:
    return APIResponse(
        status="success",
        message=message,
        data=normalize_data(data),
        request_id=request_id,
    ).model_dump(by_alias=True, exclude_none=True)


def error_payload(
    *,
    message: str = "Request failed",
    data: Any = None,
    request_id: Optional[str] = None,
) -> Dict[str, Any]:
    return APIResponse(
        status="error",
        message=message,
        data=normalize_data(data),
        request_id=request_id,
    ).model_dump(by_alias=True, exclude_none=True)
