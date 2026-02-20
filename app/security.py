import os
import re
from typing import Optional, Dict, Any

from fastapi import Depends, HTTPException, Request, status
from starlette.requests import HTTPConnection

from .utils.firestore_client import verify_firebase_token


_USER_ID_RE = re.compile(r"^[A-Za-z0-9_-]{3,128}$")


def _env_bool(name: str, default: bool = False) -> bool:
    value = os.getenv(name)
    if value is None:
        return default
    return value.strip().lower() in {"1", "true", "yes", "on"}


def _is_local_client(connection: HTTPConnection) -> bool:
    host = (connection.client.host if connection.client else "").strip().lower()
    return host in {"127.0.0.1", "::1", "localhost"}


def _allow_dev_user_id() -> bool:
    explicit = os.getenv("ALLOW_DEV_USER_ID")
    if explicit is None:
        # Secure-by-default: explicit opt-in only.
        return False
    return explicit.strip().lower() in {"1", "true", "yes", "on"}


def _is_valid_user_id(user_id: str) -> bool:
    return bool(_USER_ID_RE.match((user_id or "").strip()))


def _extract_bearer_token(auth_header: Optional[str]) -> Optional[str]:
    if not auth_header:
        return None
    if auth_header.lower().startswith("bearer "):
        return auth_header.split(" ", 1)[1].strip()
    return None


def _dev_auth_header_valid(connection: HTTPConnection) -> bool:
    shared_secret = (os.getenv("DEV_AUTH_SHARED_SECRET") or "").strip()
    if not shared_secret:
        return True
    provided = (connection.headers.get("x-dev-auth") or "").strip()
    return provided == shared_secret


def resolve_dev_user(connection: HTTPConnection) -> Optional[str]:
    requested_user = (
        connection.headers.get("x-user-id")
        or connection.query_params.get("user_id")
    )
    if not requested_user:
        return None
    requested_user = requested_user.strip()
    if not _is_valid_user_id(requested_user):
        return None
    if not _allow_dev_user_id():
        return None

    localhost_only = _env_bool("DEV_USER_LOCALHOST_ONLY", True)
    if localhost_only and not _is_local_client(connection):
        return None

    if not _dev_auth_header_valid(connection):
        return None

    return requested_user


async def get_token_claims(
    connection: HTTPConnection,
) -> Dict[str, Any]:
    dev_user = resolve_dev_user(connection)
    if dev_user:
        return _dev_claims(dev_user)

    token = _extract_bearer_token(connection.headers.get("authorization"))
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


async def verify_http_request(request: Request) -> Dict[str, Any]:
    dev_user = resolve_dev_user(request)
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
