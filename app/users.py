from fastapi import APIRouter, HTTPException, Header
from pydantic import BaseModel, EmailStr
from typing import Optional
from datetime import datetime

# Pydantic models for data validation and response shapes
class User(BaseModel):
    id: str
    email: EmailStr
    name: str
    created_at: datetime
    preferences: Optional[dict] = None
    avatarUrl: Optional[str] = None # Added to match original model

class UserUpdateRequest(BaseModel):
    name: Optional[str] = None
    email: Optional[EmailStr] = None
    preferences: Optional[dict] = None

# This is a dummy user database for demonstration.
# In a real application, you would fetch this from a database.
mock_users = {
    "user_123": {
        "id": "user-123",
        "email": "demo@forexcompanion.com",
        "name": "Demo User",
        "created_at": "2026-01-17T00:00:00",
        "avatarUrl": "https://i.pravatar.cc/150",
        "preferences": {},
    }
}

router = APIRouter(
    prefix="/api/users",
    tags=["Users"],
)

@router.get("/me", response_model=User)
async def read_current_user(authorization: Optional[str] = Header(None)):
    """
    Get the current authenticated user.

    In a real app, you would get the user based on an auth token.
    """
    # TODO: Implement JWT token verification
    user_id = "user_123"  # In production, extract from JWT token

    if user_id not in mock_users:
        raise HTTPException(status_code=404, detail="User not found")

    return mock_users[user_id]

@router.put("/me", response_model=User)
async def update_current_user(
    user_update: UserUpdateRequest,
    authorization: Optional[str] = Header(None)
):
    """
    Update current user information.

    Allows users to update their profile information.
    """
    # TODO: Implement JWT token verification
    user_id = "user_123"  # In production, extract from JWT token

    if user_id not in mock_users:
        raise HTTPException(status_code=404, detail="User not found")

    # Update user data
    current_user = mock_users[user_id]
    # Get update data, excluding fields that were not set and fields that are None.
    update_data = user_update.model_dump(exclude_unset=True, exclude_none=True)

    # Update the user's data dictionary
    current_user.update(update_data)

    return current_user

@router.get("/me/preferences")
async def get_user_preferences(authorization: Optional[str] = Header(None)):
    """Get user preferences"""
    user_id = "user_123"

    if user_id not in mock_users:
        raise HTTPException(status_code=404, detail="User not found")

    return mock_users[user_id].get("preferences", {})