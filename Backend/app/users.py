from fastapi import APIRouter
from pydantic import BaseModel, EmailStr
from typing import Optional

# Pydantic models for data validation and response shapes
class User(BaseModel):
    id: str = "user-123"
    name: str = "Default User"
    email: EmailStr = "user@example.com"
    avatarUrl: Optional[str] = None

class UserUpdateRequest(BaseModel):
    name: Optional[str] = None
    email: Optional[EmailStr] = None

# This is a dummy user database for demonstration.
# In a real application, you would fetch this from a database.
fake_user_db = {
    "user-123": {
        "id": "user-123",
        "name": "Alex Doe",
        "email": "alex.doe@example.com",
        "avatarUrl": "https://i.pravatar.cc/150"
    }
}

router = APIRouter(
    prefix="/api/users",
    tags=["Users"]
)

@router.get("/me", response_model=User)
async def read_current_user():
    """
    Get the current authenticated user.
    In a real app, you would get the user based on an auth token.
    """
    # For now, we return a hardcoded user to satisfy the frontend.
    return fake_user_db["user-123"]

@router.put("/me", response_model=User)
async def update_current_user(user_update: UserUpdateRequest):
    """Update the current authenticated user's profile."""
    user = fake_user_db["user-123"]
    update_data = user_update.model_dump(exclude_unset=True, exclude_none=True)
    user.update(update_data)
    return user