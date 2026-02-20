from typing import Optional

from fastapi import APIRouter, Depends, HTTPException
from fastapi.responses import JSONResponse
from pydantic import BaseModel
from .security import get_current_user_id
from .services.broker_execution_service import broker_execution_service
from .services.credential_vault_service import credential_vault_service
from .services.subscription_service import subscription_service

router = APIRouter(
    prefix="/api/accounts",
    tags=["accounts"],
)

class ConnectAccountRequest(BaseModel):
    username: str
    password: str
    save_credentials: bool = True
    credential_label: Optional[str] = None


class ConnectUsingVaultRequest(BaseModel):
    credential_id: Optional[str] = None

class DisconnectAccountRequest(BaseModel):
    account_id: str

@router.get("/connections")
async def get_account_connections(user_id: str = Depends(get_current_user_id)):
    """Get all account connections for the current user"""
    try:
        connections = broker_execution_service.get_account_connections(user_id)
        return JSONResponse(content={
            "success": True,
            "connections": connections
        }, status_code=200)
    except Exception as e:
        return JSONResponse(content={
            "success": False,
            "error": str(e)
        }, status_code=500)

@router.post("/connect/forex")
async def connect_forex_account(
    request: ConnectAccountRequest,
    user_id: str = Depends(get_current_user_id),
):
    """Connect to Forex.com account"""
    try:
        username = request.username
        password = request.password
        
        if not username or not password:
            raise HTTPException(status_code=400, detail="Username and password are required")

        account_mode = broker_execution_service.infer_account_mode(username)
        if account_mode == "live":
            subscription_service.ensure_feature_access(
                user_id=user_id,
                feature="live_broker_execution",
            )
        
        connection = broker_execution_service.connect_forex_account(
            user_id=user_id,
            username=username,
            password=password,
        )

        saved_credential = None
        vault_warning = None
        if request.save_credentials:
            try:
                subscription_service.ensure_feature_access(
                    user_id=user_id,
                    feature="credential_vault",
                )
                saved_credential = credential_vault_service.store_forex_credentials(
                    user_id=user_id,
                    username=username,
                    password=password,
                    label=request.credential_label,
                    metadata={
                        "mode": account_mode,
                        "account_id": connection.get("id"),
                    },
                )
            except HTTPException:
                raise
            except Exception as vault_exc:
                vault_warning = f"Connected but credential vault save skipped: {vault_exc}"

        return JSONResponse(content={
            "success": True,
            "connection": connection,
            "credential_vault": saved_credential,
            "vault_warning": vault_warning,
            "message": "Successfully connected to Forex.com"
        }, status_code=200)
    except HTTPException as e:
        raise e
    except Exception as e:
        return JSONResponse(content={
            "success": False,
            "error": str(e)
        }, status_code=500)


@router.post("/connect/forex/from-vault")
async def connect_forex_account_from_vault(
    request: ConnectUsingVaultRequest,
    user_id: str = Depends(get_current_user_id),
):
    """Connect to Forex.com account by retrieving encrypted credentials from vault."""
    try:
        subscription_service.ensure_feature_access(
            user_id=user_id,
            feature="credential_vault",
        )
        vault_credential = credential_vault_service.get_forex_credentials(
            user_id=user_id,
            credential_id=request.credential_id,
        )

        account_mode = str(vault_credential.get("mode") or "demo").strip().lower()
        if account_mode == "live":
            subscription_service.ensure_feature_access(
                user_id=user_id,
                feature="live_broker_execution",
            )

        connection = broker_execution_service.connect_forex_account(
            user_id=user_id,
            username=str(vault_credential.get("username") or ""),
            password=str(vault_credential.get("password") or ""),
        )
        return JSONResponse(
            content={
                "success": True,
                "connection": connection,
                "credential_id": vault_credential.get("credential_id"),
                "message": "Successfully connected to Forex.com via credential vault",
            },
            status_code=200,
        )
    except HTTPException as exc:
        raise exc
    except ValueError as exc:
        raise HTTPException(status_code=400, detail=str(exc)) from exc
    except RuntimeError as exc:
        raise HTTPException(status_code=503, detail=str(exc)) from exc
    except Exception as exc:
        return JSONResponse(content={"success": False, "error": str(exc)}, status_code=500)

@router.post("/disconnect")
async def disconnect_account(
    request: DisconnectAccountRequest,
    user_id: str = Depends(get_current_user_id),
):
    """Disconnect an account"""
    try:
        account_id = request.account_id
        
        if not account_id:
            raise HTTPException(status_code=400, detail="Account ID is required")
        
        removed = broker_execution_service.disconnect_account(
            user_id=user_id,
            account_id=account_id,
        )
        if not removed:
            raise HTTPException(status_code=404, detail="Account not found")

        return JSONResponse(content={
            "success": True,
            "message": "Account disconnected successfully"
        }, status_code=200)
    except HTTPException as e:
        raise e
    except Exception as e:
        return JSONResponse(content={
            "success": False,
            "error": str(e)
        }, status_code=500)

@router.get("/{account_id}/balance")
async def get_account_balance(
    account_id: str,
    user_id: str = Depends(get_current_user_id),
):
    """Get current account balance"""
    try:
        balance_data = broker_execution_service.get_account_balance(
            user_id=user_id,
            account_id=account_id,
        )
        if not balance_data:
            raise HTTPException(status_code=404, detail="Account not found")

        balance, currency = balance_data
        return JSONResponse(content={
            "success": True,
            "balance": balance,
            "currency": currency
        }, status_code=200)
    except Exception as e:
        return JSONResponse(content={
            "success": False,
            "error": str(e)
        }, status_code=500)

@router.get("/trading-info")
async def get_trading_info():
    """Get trading information for the connected account"""
    try:
        info = {
            "leverage": "1:50",
            "margin": "3.5%",
            "free_margin": 1234.56,
            "used_margin": 45.67,
            "margin_level": "87%"
        }
        
        return JSONResponse(content={
            "success": True,
            "trading_info": info
        }, status_code=200)
    except Exception as e:
        return JSONResponse(content={
            "success": False,
            "error": str(e)
        }, status_code=500)
