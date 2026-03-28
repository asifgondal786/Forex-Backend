from fastapi import APIRouter, HTTPException, Depends
from pydantic import BaseModel, EmailStr
from typing import Optional
from datetime import datetime, timezone

from .security import get_token_claims
from .services.subscription_service import subscription_service
from app.database import supabase


class User(BaseModel):
    id: str
    email: str
    name: str
    plan: str = "free"
    created_at: Optional[str] = None
    preferences: Optional[dict] = None
    avatar_url: Optional[str] = None


class UserUpdateRequest(BaseModel):
    name: Optional[str] = None
    email: Optional[EmailStr] = None
    preferences: Optional[dict] = None
    avatar_url: Optional[str] = None


async def get_current_user(claims: dict = Depends(get_token_claims)) -> dict:
    user_id = claims.get("uid") or claims.get("user_id")
    if not user_id:
        raise HTTPException(status_code=401, detail="Invalid Firebase token payload")

    email = claims.get("email") or ""
    name = claims.get("name") or (email.split("@")[0] if email else "User")
    subscription = subscription_service.get_subscription(user_id)
    plan = str(subscription.get("plan") or "free")

    # Try to fetch existing user from Supabase
    result = supabase.table("users").select("*").eq("id", user_id).execute()
    existing = result.data[0] if result.data else None

    if not existing:
        # Create new user row
        new_user = {
            "id":          user_id,
            "email":       email,
            "name":        name,
            "plan":        plan,
            "preferences": {},
            "avatar_url":  None,
            "created_at":  datetime.now(timezone.utc).isoformat(),
        }
        supabase.table("users").upsert(new_user, on_conflict="id").execute()
        return new_user
    else:
        # Update email/name/plan if changed
        updates = {}
        if email and existing.get("email") != email:
            updates["email"] = email
        if name and existing.get("name") != name:
            updates["name"] = name
        if existing.get("plan") != plan:
            updates["plan"] = plan
        if updates:
            supabase.table("users").update(updates).eq("id", user_id).execute()
            existing.update(updates)
        return existing


router = APIRouter(prefix="/users", tags=["Users"])


@router.get("/me", response_model=User)
async def read_current_user(current_user: dict = Depends(get_current_user)):
    return current_user


@router.put("/me", response_model=User)
async def update_current_user(
    user_update: UserUpdateRequest,
    current_user: dict = Depends(get_current_user),
):
    user_id = current_user["id"]
    update_data = user_update.model_dump(exclude_unset=True, exclude_none=True)
    if not update_data:
        raise HTTPException(400, "No fields to update")

    supabase.table("users").update(update_data).eq("id", user_id).execute()

    # Return updated user
    result = supabase.table("users").select("*").eq("id", user_id).execute()
    return result.data[0] if result.data else {**current_user, **update_data}


@router.get("/me/preferences")
async def get_user_preferences(current_user: dict = Depends(get_current_user)):
    return current_user.get("preferences") or {}