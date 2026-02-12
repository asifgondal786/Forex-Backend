from fastapi import APIRouter, Depends, HTTPException
from fastapi.responses import JSONResponse
from pydantic import BaseModel
from app.security import verify_http_request

router = APIRouter(
    prefix="/api/accounts",
    tags=["accounts"],
    dependencies=[Depends(verify_http_request)]
)

class ConnectAccountRequest(BaseModel):
    username: str
    password: str

class DisconnectAccountRequest(BaseModel):
    account_id: str

@router.get("/connections")
async def get_account_connections():
    """Get all account connections for the current user"""
    try:
        # For now, return mock data using user's demo account
        connections = [
            {
                "id": "demo-gondalgondal0000vlk2",
                "broker": "Forex.com",
                "account_number": "demo-gondalgondal0000vlk2",
                "balance": 10000.00,
                "currency": "USD",
                "status": "connected",
                "last_updated": "2024-01-15T10:30:00Z"
            }
        ]
        
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
async def connect_forex_account(request: ConnectAccountRequest):
    """Connect to Forex.com account"""
    try:
        username = request.username
        password = request.password
        
        if not username or not password:
            raise HTTPException(status_code=400, detail="Username and password are required")
        
        # In real implementation, we would validate credentials with Forex.com API
        connection = {
            "id": f"forex_{username.lower()}",
            "broker": "Forex.com",
            "account_number": f"FX_{username[-5:]}",
            "balance": 10000.00,
            "currency": "USD",
            "status": "connected",
            "last_updated": "2024-01-15T10:30:00Z"
        }
        
        return JSONResponse(content={
            "success": True,
            "connection": connection,
            "message": "Successfully connected to Forex.com"
        }, status_code=200)
    except HTTPException as e:
        raise e
    except Exception as e:
        return JSONResponse(content={
            "success": False,
            "error": str(e)
        }, status_code=500)

@router.post("/disconnect")
async def disconnect_account(request: DisconnectAccountRequest):
    """Disconnect an account"""
    try:
        account_id = request.account_id
        
        if not account_id:
            raise HTTPException(status_code=400, detail="Account ID is required")
        
        # In real implementation, we would revoke access tokens and update database
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
async def get_account_balance(account_id: str):
    """Get current account balance"""
    try:
        # In real implementation, we would fetch balance from broker API
        if account_id == "demo-gondalgondal0000vlk2":
            return JSONResponse(content={
                "success": True,
                "balance": 10000.00,
                "currency": "USD"
            }, status_code=200)
        else:
            return JSONResponse(content={
                "success": True,
                "balance": 10000.00,
                "currency": "USD"
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