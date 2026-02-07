import os
from typing import Optional, Dict, Any

from fastapi import Depends, Header, HTTPException, Request, status
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials

from .utils.firestore_client import verify_firebase_token

security = HTTPBearer(auto_error=False)


def _allow_dev_user_id() -> bool:
    return os.getenv("ALLOW_DEV_USER_ID", "").lower() == "true"


async def get_token_claims(
    credentials: Optional[HTTPAuthorizationCredentials] = Depends(security),
    x_user_id: Optional[str] = Header(default=None),
) -> Dict[str, Any]:
    if x_user_id and _allow_dev_user_id():
        return _dev_claims(x_user_id)

    if credentials is None:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Missing Authorization header",
        )

    try:
        return verify_firebase_token(credentials.credentials)
    except Exception:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid Firebase token",
        )


async def get_current_user_id(
    claims: Dict[str, Any] = Depends(get_token_claims),
) -> str:
    user_id = claims.get("uid") or claims.get("user_id")
    if not user_id:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid Firebase token payload",
        )
    return user_id


def _dev_claims(user_id: str) -> Dict[str, Any]:
    return {
        "uid": user_id,
        "email": f"{user_id}@example.com",
        "name": "Dev User",
        "dev": True,
    }


def _extract_bearer_token(auth_header: Optional[str]) -> Optional[str]:
    if not auth_header:
        return None
    if auth_header.lower().startswith("bearer "):
        return auth_header.split(" ", 1)[1].strip()
    return None


async def verify_http_request(request: Request) -> Dict[str, Any]:
    if _allow_dev_user_id():
        dev_user = request.headers.get("x-user-id")
        if dev_user:
            return _dev_claims(dev_user)

    token = _extract_bearer_token(request.headers.get("authorization"))
    if not token:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Missing Authorization header",
        )

    try:
        return verify_firebase_token(token)
    except Exception:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid Firebase token",
        )
