from typing import Any, Dict, Optional

from pydantic import BaseModel, Field


class SettingsResponse(BaseModel):
    user_id: str
    settings: Dict[str, Any]
    created_at: Optional[str] = None
    updated_at: Optional[str] = None


class SettingsUpdateRequest(BaseModel):
    settings: Dict[str, Any] = Field(default_factory=dict)
    replace: bool = False
