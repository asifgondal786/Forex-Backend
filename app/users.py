from fastapi import APIRouter, HTTPException, Depends
from pydantic import BaseModel, EmailStr
from typing import Optional
from datetime import datetime

from .security import get_token_claims

# Pydantic models for data validation and response shapes
class User(BaseModel):
    id: str
    email: EmailStr
    name: str
    created_at: datetime
    preferences: Optional[dict] = None
    avatar_url: Optional[str] = None

class UserUpdateRequest(BaseModel):
    name: Optional[str] = None
    email: Optional[EmailStr] = None
    preferences: Optional[dict] = None

# In-memory user store (replace with Firestore or DB in production)
users_db = {}


async def get_current_user(
    claims: dict = Depends(get_token_claims),
) -> dict:
    user_id = claims.get("uid") or claims.get("user_id")
    if not user_id:
        raise HTTPException(status_code=401, detail="Invalid Firebase token payload")

    email = claims.get("email") or ""
    name = claims.get("name") or (email.split("@")[0] if email else "User")

    user = users_db.get(user_id)
    if not user:
        user = {
            "id": user_id,
            "email": email,
            "name": name,
            "created_at": datetime.utcnow().isoformat(),
            "avatar_url": None,
            "preferences": {},
        }
        users_db[user_id] = user
    else:
        if email:
            user["email"] = email
        if name:
            user["name"] = name
        users_db[user_id] = user

    return user

router = APIRouter(
    prefix="/api/users",
    tags=["Users"],
)

@router.get("/me", response_model=User)
async def read_current_user(current_user: dict = Depends(get_current_user)):
    """
    Get the current authenticated user.

    In a real app, you would get the user based on an auth token.
    """
    return current_user

@router.put("/me", response_model=User)
async def update_current_user(
    user_update: UserUpdateRequest,
    current_user: dict = Depends(get_current_user),
):
    """
    Update current user information.

    Allows users to update their profile information.
    """
    def _normalize_avatar(data):
        if "avatar_url" in data:
            return data
        if "avatarUrl" in data:
            data["avatar_url"] = data.pop("avatarUrl")
        return data

    user_id = current_user["id"]
    update_data = user_update.model_dump(exclude_unset=True, exclude_none=True)
    update_data = _normalize_avatar(update_data)
    users_db[user_id] = _normalize_avatar({**current_user, **update_data})
    return users_db[user_id]

@router.get("/me/preferences")
async def get_user_preferences(current_user: dict = Depends(get_current_user)):
    """Get user preferences"""
    return current_user.get("preferences", {})
