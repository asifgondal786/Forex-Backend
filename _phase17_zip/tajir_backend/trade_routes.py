from fastapi import APIRouter, Depends, Body, HTTPException
from app.auth import get_current_user
from app.limiter import limiter
from app.database import supabase
from app.services.trade_token_service import generate_trade_token, consume_trade_token
from fastapi import Request
from datetime import datetime, timezone
import uuid

router = APIRouter(prefix="/api/v1/trades", tags=["trades"])


@router.post("/paper/open")
@limiter.limit("30/minute")
async def open_paper_trade(
    request: Request,
    body: dict = Body(...),
    current_user=Depends(get_current_user)
):
    """
    Execute a paper trade. Called after TradeExecutionProvider.executeTrade().

    Body: {
      "pair":        "EUR/USD",
      "direction":   "buy" | "sell",
      "lot_size":    0.01,
      "leverage":    10,
      "stop_loss":   1.0820,       (optional)
      "take_profit": 1.0900,       (optional)
      "entry_price": 1.08450       (optional — uses latest market price if omitted)
    }

    Flow:
      1. Validate inputs
      2. Fetch current market price if entry_price not supplied
      3. Insert row into paper_trades with status='open'
      4. Return the created trade matching OpenTrade model shape
    """
    uid = str(current_user["uid"])

    pair      = body.get("pair", "").strip()
    direction = body.get("direction", "").lower()
    lot_size  = float(body.get("lot_size", 0.01))
    leverage  = float(body.get("leverage", 1.0))
    stop_loss = body.get("stop_loss")
    take_profit = body.get("take_profit")
    entry_price = body.get("entry_price")

    # Validate
    if not pair:
        raise HTTPException(400, "pair is required")
    if direction not in ("buy", "sell"):
        raise HTTPException(400, "direction must be 'buy' or 'sell'")
    if lot_size <= 0:
        raise HTTPException(400, "lot_size must be > 0")
    if leverage < 1:
        raise HTTPException(400, "leverage must be >= 1")

    # If no entry price supplied, try to fetch from market_prices table
    if entry_price is None:
        price_row = supabase.table("market_prices") \
            .select("bid").eq("pair", pair.replace("/", "_")) \
            .limit(1).execute()
        if price_row.data:
            entry_price = float(price_row.data[0]["bid"])
        else:
            # Fallback to a reasonable default for common pairs
            fallbacks = {
                "EUR/USD": 1.08450, "GBP/USD": 1.26300,
                "USD/JPY": 149.500, "GBP/JPY": 188.500,
                "AUD/USD": 0.65100, "USD/CHF": 0.89800,
                "XAU/USD": 2340.00,
            }
            entry_price = fallbacks.get(pair, 1.00000)

    now = datetime.now(timezone.utc).isoformat()
    trade_id = str(uuid.uuid4())

    supabase.table("paper_trades").insert({
        "id":             trade_id,
        "user_id":        uid,
        "pair":           pair,
        "direction":      direction,
        "entry_price":    round(float(entry_price), 5),
        "lot_size":       lot_size,
        "leverage":       leverage,
        "stop_loss":      round(float(stop_loss), 5) if stop_loss else None,
        "take_profit":    round(float(take_profit), 5) if take_profit else None,
        "status":         "open",
        "unrealized_pnl": 0.0,
        "realized_pnl":   None,
        "opened_at":      now,
    }).execute()

    return {
        "id":           trade_id,
        "pair":         pair,
        "direction":    direction.upper(),
        "entry_price":  round(float(entry_price), 5),
        "lot_size":     lot_size,
        "leverage":     leverage,
        "stop_loss":    round(float(stop_loss), 5) if stop_loss else None,
        "take_profit":  round(float(take_profit), 5) if take_profit else None,
        "opened_at":    now,
        "pnl":          0.0,
        "status":       "open",
        "message":      f"Paper trade opened: {direction.upper()} {pair} at {entry_price}",
    }


@router.post("/paper/close/{trade_id}")
@limiter.limit("30/minute")
async def close_paper_trade(
    request: Request,
    trade_id: str,
    body: dict = Body(default={}),
    current_user=Depends(get_current_user)
):
    """
    Close an open paper trade. Maps to PortfolioProvider.closeTrade().
    Optionally accepts an exit_price; otherwise simulates a small move.
    """
    uid = str(current_user["uid"])

    row = supabase.table("paper_trades") \
        .select("*").eq("id", trade_id).eq("user_id", uid) \
        .eq("status", "open").limit(1).execute()

    if not row.data:
        raise HTTPException(404, "Open trade not found")

    trade = row.data[0]
    entry     = float(trade["entry_price"])
    direction = trade["direction"]
    lot       = float(trade.get("lot_size") or 0.01)

    exit_price = body.get("exit_price")
    if exit_price is None:
        exit_price = entry * 1.0008 if direction == "buy" else entry * 0.9992

    exit_price = round(float(exit_price), 5)
    diff = (exit_price - entry) if direction == "buy" else (entry - exit_price)
    realized_pnl = round(diff * lot * 10000, 2)
    now = datetime.now(timezone.utc).isoformat()

    supabase.table("paper_trades").update({
        "status":       "closed",
        "exit_price":   exit_price,
        "realized_pnl": realized_pnl,
        "closed_at":    now,
        "unrealized_pnl": 0.0,
    }).eq("id", trade_id).eq("user_id", uid).execute()

    return {
        "id":           trade_id,
        "pair":         trade["pair"],
        "direction":    direction.upper(),
        "entry_price":  entry,
        "exit_price":   exit_price,
        "lot_size":     lot,
        "realized_pnl": realized_pnl,
        "closed_at":    now,
        "message":      "Trade closed successfully",
    }


@router.get("/paper/open")
async def list_open_trades(current_user=Depends(get_current_user)):
    """List open paper trades. Alias kept for backward compat with existing routes."""
    uid = str(current_user["uid"])
    rows = supabase.table("paper_trades") \
        .select("id, pair, direction, entry_price, lot_size, leverage, stop_loss, take_profit, opened_at, unrealized_pnl") \
        .eq("user_id", uid).eq("status", "open") \
        .order("opened_at", desc=True).execute()

    trades = [{
        "id":          r["id"],
        "pair":        r["pair"],
        "direction":   r["direction"].upper(),
        "entry_price": r["entry_price"],
        "lot_size":    r.get("lot_size", 0.01),
        "leverage":    r.get("leverage", 1),
        "stop_loss":   r.get("stop_loss"),
        "take_profit": r.get("take_profit"),
        "opened_at":   r["opened_at"],
        "pnl":         round(r.get("unrealized_pnl") or 0, 2),
    } for r in (rows.data or [])]

    return {"trades": trades}
