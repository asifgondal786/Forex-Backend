"""
Authentication Routes
Handles user signup, login, logout, and verification
"""
from fastapi import APIRouter, HTTPException, status, Depends
from pydantic import BaseModel, EmailStr
from datetime import datetime, timedelta
from typing import Optional
import secrets
import hashlib
# from app.models.user_model import User  # Removed because module could not be resolved and 'User' is not used in this file
from app.services.auth_service import AuthService

router = APIRouter(prefix="/api/auth", tags=["auth"])

# Models
class SignupRequest(BaseModel):
    email: EmailStr
    password: str
    username: str
    full_name: str

class LoginRequest(BaseModel):
    email: EmailStr
    password: str

class VerifyRequest(BaseModel):
    token: str

# Auth service instance
auth_service = AuthService()

@router.post("/signup")
async def signup(request: SignupRequest):
    """Register a new user"""
    try:
        result = await auth_service.signup(
            email=request.email,
            username=request.username,
            password=request.password,
            full_name=request.full_name,
        )
        return result
    except ValueError as e:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=str(e)
        )
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=str(e)
        )

@router.post("/login")
async def login(request: LoginRequest):
    """Login user and return JWT token"""
    try:
        result = await auth_service.login(
            email=request.email,
            password=request.password,
        )
        return result
    except ValueError as e:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail=str(e)
        )
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=str(e)
        )

@router.post("/logout")
async def logout(current_user: dict = Depends(auth_service.get_current_user)):
    """Logout user (token invalidation)"""
    return {
        "success": True,
        "message": "Logged out successfully"
    }

@router.post("/verify")
async def verify_token(request: VerifyRequest):
    """Verify JWT token validity"""
    try:
        is_valid = auth_service.verify_token(request.token)
        return {
            "success": is_valid,
            "message": "Token is valid" if is_valid else "Invalid token"
        }
    except Exception as e:
        return {
            "success": False,
            "message": str(e)
        }

@router.post("/refresh")
async def refresh_token(current_user: dict = Depends(auth_service.get_current_user)):
    """Refresh JWT token"""
    try:
        new_token = auth_service.create_access_token(
            data={"sub": current_user["id"]}
        )
        return {
            "success": True,
            "token": new_token,
            "message": "Token refreshed"
        }
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=str(e)
        )
