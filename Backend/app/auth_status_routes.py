from typing import Dict, Any

from fastapi import APIRouter, Depends

from .security import get_token_claims

router = APIRouter(prefix="/api/auth", tags=["Auth"])


@router.get("/status")
async def auth_status(claims: Dict[str, Any] = Depends(get_token_claims)):
    """Minimal auth status check."""
    uid = claims.get("uid") or claims.get("user_id")
    return {
        "authenticated": True,
        "uid": uid,
        "email": claims.get("email"),
        "name": claims.get("name"),
        "dev": claims.get("dev", False),
        "token": {
            "iss": claims.get("iss"),
            "aud": claims.get("aud"),
            "auth_time": claims.get("auth_time"),
            "iat": claims.get("iat"),
            "exp": claims.get("exp"),
        },
    }


@router.get("/claims")
async def auth_claims(claims: Dict[str, Any] = Depends(get_token_claims)):
    """Return full Firebase token claims (debug)."""
    return {"claims": claims}
