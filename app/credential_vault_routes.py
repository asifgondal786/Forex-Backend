from __future__ import annotations

from typing import Any, Dict, Optional

from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel

from .security import get_current_user_id
from .services.credential_vault_service import credential_vault_service
from .services.subscription_service import subscription_service

router = APIRouter(prefix="/api/credentials", tags=["Credential Vault"])


class SaveForexCredentialRequest(BaseModel):
    username: str
    password: str
    label: Optional[str] = None
    metadata: Optional[Dict[str, Any]] = None


@router.get("/status")
async def get_vault_status(user_id: str = Depends(get_current_user_id)):
    _ = user_id
    return {
        "enabled": credential_vault_service.is_enabled,
        "key_mode": credential_vault_service.key_mode,
    }


@router.get("/forex")
async def list_forex_credentials(user_id: str = Depends(get_current_user_id)):
    subscription_service.ensure_feature_access(user_id=user_id, feature="credential_vault")
    items = credential_vault_service.list_forex_credentials(user_id)
    return {
        "success": True,
        "provider": "forex_com",
        "credentials": items,
        "count": len(items),
    }


@router.post("/forex")
async def save_forex_credentials(
    request: SaveForexCredentialRequest,
    user_id: str = Depends(get_current_user_id),
):
    subscription_service.ensure_feature_access(user_id=user_id, feature="credential_vault")
    try:
        saved = credential_vault_service.store_forex_credentials(
            user_id=user_id,
            username=request.username,
            password=request.password,
            label=request.label,
            metadata=request.metadata,
        )
    except ValueError as exc:
        raise HTTPException(status_code=400, detail=str(exc)) from exc
    except RuntimeError as exc:
        raise HTTPException(status_code=503, detail=str(exc)) from exc

    return {
        "success": True,
        "provider": "forex_com",
        "credential": saved,
        "message": "Credentials encrypted and stored in vault.",
    }


@router.delete("/forex/{credential_id}")
async def delete_forex_credential(
    credential_id: str,
    user_id: str = Depends(get_current_user_id),
):
    subscription_service.ensure_feature_access(user_id=user_id, feature="credential_vault")
    removed = credential_vault_service.delete_credential(user_id=user_id, credential_id=credential_id)
    if not removed:
        raise HTTPException(status_code=404, detail="Credential record not found")
    return {
        "success": True,
        "credential_id": credential_id,
        "message": "Credential removed from vault.",
    }
