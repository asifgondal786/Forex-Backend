from fastapi import APIRouter, Depends, Body, HTTPException
from app.auth import get_current_user
from app.limiter import limiter
from app.database import supabase
from fastapi import Request
from datetime import datetime, timezone, date
from typing import Optional

router = APIRouter(prefix="/api/v1/portfolio", tags=["portfolio"])


# ─── Stats ────────────────────────────────────────────────────────────────────

@router.get("/stats")
async def get_stats(current_user=Depends(get_current_user)):
    """
    Compute and return portfolio statistics.
    Maps to PortfolioProvider._computeStats() → PortfolioStats model.

    Response shape:
      equity, balance, daily_pnl, win_rate, avg_win, avg_loss,
      win_streak, equity_curve (list of floats)
    """
    uid = str(current_user["uid"])
    start_balance = 10000.0

    # Open trades
    open_rows = supabase.table("paper_trades") \
        .select("unrealized_pnl") \
        .eq("user_id", uid).eq("status", "open").execute()

    open_pnl = sum((r.get("unrealized_pnl") or 0) for r in (open_rows.data or []))

    # Closed trades
    closed_rows = supabase.table("paper_trades") \
        .select("realized_pnl, closed_at") \
        .eq("user_id", uid).eq("status", "closed") \
        .order("closed_at", desc=True).execute()

    closed = closed_rows.data or []
    closed_pnl = sum((r.get("realized_pnl") or 0) for r in closed)
    equity = start_balance + closed_pnl + open_pnl

    # Daily P&L
    today_str = date.today().isoformat()
    today_closed_pnl = sum(
        (r.get("realized_pnl") or 0) for r in closed
        if r.get("closed_at", "")[:10] == today_str
    )
    daily_pnl = today_closed_pnl + open_pnl

    # Win rate
    wins   = [r for r in closed if (r.get("realized_pnl") or 0) > 0]
    losses = [r for r in closed if (r.get("realized_pnl") or 0) <= 0]
    total  = len(closed)
    win_rate = (len(wins) / total * 100) if total > 0 else 0.0
    avg_win  = (sum(r["realized_pnl"] for r in wins) / len(wins)) if wins else 0.0
    avg_loss = (sum(abs(r["realized_pnl"]) for r in losses) / len(losses)) if losses else 0.0

    # Win streak (most recent consecutive wins)
    streak = 0
    for r in closed:
        if (r.get("realized_pnl") or 0) > 0:
            streak += 1
        else:
            break

    # Equity curve
    running = start_balance
    curve = [running]
    for r in reversed(closed):
        running += (r.get("realized_pnl") or 0)
        curve.append(running)
    curve.append(equity)

    return {
        "equity":        round(equity, 2),
        "balance":       round(start_balance + closed_pnl, 2),
        "daily_pnl":     round(daily_pnl, 2),
        "win_rate":      round(win_rate, 2),
        "avg_win":       round(avg_win, 2),
        "avg_loss":      round(avg_loss, 2),
        "win_streak":    streak,
        "equity_curve":  [round(v, 2) for v in curve],
        "open_count":    len(open_rows.data or []),
        "closed_count":  total,
    }


# ─── Open trades ──────────────────────────────────────────────────────────────

@router.get("/trades/open")
async def get_open_trades(current_user=Depends(get_current_user)):
    """
    Return all open paper trades.
    Maps to PortfolioProvider.openTrades → List<OpenTrade>.

    Response shape matches OpenTrade model:
      id, pair, direction, entry_price, lot_size, leverage,
      stop_loss, take_profit, opened_at, pnl (unrealized)
    """
    uid = str(current_user["uid"])
    rows = supabase.table("paper_trades") \
        .select("id, pair, direction, entry_price, lot_size, stop_loss, take_profit, opened_at, unrealized_pnl") \
        .eq("user_id", uid).eq("status", "open") \
        .order("opened_at", desc=True).execute()

    trades = []
    for r in (rows.data or []):
        trades.append({
            "id":           r["id"],
            "pair":         r["pair"],
            "direction":    r["direction"].upper(),
            "entry_price":  r["entry_price"],
            "lot_size":     r.get("lot_size", 0.01),
            "leverage":     r.get("leverage", 1),
            "stop_loss":    r.get("stop_loss"),
            "take_profit":  r.get("take_profit"),
            "opened_at":    r["opened_at"],
            "pnl":          round(r.get("unrealized_pnl") or 0, 2),
        })

    return {"trades": trades, "count": len(trades)}


@router.post("/trades/open/{trade_id}/close")
@limiter.limit("20/minute")
async def close_trade(
    request: Request,
    trade_id: str,
    current_user=Depends(get_current_user)
):
    """
    Close an open paper trade by id.
    Maps to PortfolioProvider.closeTrade(tradeId, token).
    Returns the closed trade with realized P&L.
    """
    uid = str(current_user["uid"])

    trade_row = supabase.table("paper_trades") \
        .select("*").eq("id", trade_id).eq("user_id", uid) \
        .eq("status", "open").limit(1).execute()

    if not trade_row.data:
        raise HTTPException(404, "Trade not found or already closed")

    trade = trade_row.data[0]
    entry = float(trade["entry_price"])
    direction = trade["direction"]

    # Simulate exit: small move from entry
    exit_price = entry * 1.0008 if direction == "buy" else entry * 0.9992
    realized_pnl = float(trade.get("unrealized_pnl") or 0)
    now = datetime.now(timezone.utc).isoformat()

    supabase.table("paper_trades").update({
        "status":       "closed",
        "exit_price":   round(exit_price, 5),
        "realized_pnl": round(realized_pnl, 2),
        "closed_at":    now,
    }).eq("id", trade_id).eq("user_id", uid).execute()

    return {
        "id":           trade_id,
        "pair":         trade["pair"],
        "direction":    direction.upper(),
        "entry_price":  entry,
        "exit_price":   round(exit_price, 5),
        "realized_pnl": round(realized_pnl, 2),
        "closed_at":    now,
        "message":      "Trade closed successfully",
    }


# ─── Trade history ────────────────────────────────────────────────────────────

@router.get("/trades/history")
async def get_trade_history(
    current_user=Depends(get_current_user),
    limit: int = 50,
    offset: int = 0
):
    """
    Return closed trade history.
    Maps to PortfolioProvider.tradeHistory → List<ClosedTrade>.

    Response shape matches ClosedTrade model:
      id, pair, direction, entry_price, exit_price, lot_size, realized_pnl, closed_at
    """
    uid = str(current_user["uid"])
    rows = supabase.table("paper_trades") \
        .select("id, pair, direction, entry_price, exit_price, lot_size, realized_pnl, closed_at") \
        .eq("user_id", uid).eq("status", "closed") \
        .order("closed_at", desc=True) \
        .range(offset, offset + limit - 1) \
        .execute()

    trades = []
    for r in (rows.data or []):
        trades.append({
            "id":           r["id"],
            "pair":         r["pair"],
            "direction":    r["direction"].upper(),
            "entry_price":  r["entry_price"],
            "exit_price":   r.get("exit_price", r["entry_price"]),
            "lot_size":     r.get("lot_size", 0.01),
            "realized_pnl": round(r.get("realized_pnl") or 0, 2),
            "closed_at":    r["closed_at"],
        })

    return {"trades": trades, "count": len(trades)}


# ─── Load all (single call for PortfolioProvider.loadAll) ────────────────────

@router.get("/all")
async def load_all(current_user=Depends(get_current_user)):
    """
    Convenience endpoint: returns stats + open trades + history in one call.
    Maps to PortfolioProvider.loadAll(token).
    """
    uid = str(current_user["uid"])
    start_balance = 10000.0

    open_rows = supabase.table("paper_trades") \
        .select("id, pair, direction, entry_price, lot_size, stop_loss, take_profit, opened_at, unrealized_pnl") \
        .eq("user_id", uid).eq("status", "open") \
        .order("opened_at", desc=True).execute()

    closed_rows = supabase.table("paper_trades") \
        .select("id, pair, direction, entry_price, exit_price, lot_size, realized_pnl, closed_at") \
        .eq("user_id", uid).eq("status", "closed") \
        .order("closed_at", desc=True).limit(100).execute()

    open_trades = []
    for r in (open_rows.data or []):
        open_trades.append({
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
        })

    closed = closed_rows.data or []
    history = []
    for r in closed:
        history.append({
            "id":           r["id"],
            "pair":         r["pair"],
            "direction":    r["direction"].upper(),
            "entry_price":  r["entry_price"],
            "exit_price":   r.get("exit_price", r["entry_price"]),
            "lot_size":     r.get("lot_size", 0.01),
            "realized_pnl": round(r.get("realized_pnl") or 0, 2),
            "closed_at":    r["closed_at"],
        })

    # Compute stats inline
    open_pnl   = sum(t["pnl"] for t in open_trades)
    closed_pnl = sum(r.get("realized_pnl") or 0 for r in closed)
    equity     = start_balance + closed_pnl + open_pnl

    today_str  = date.today().isoformat()
    daily_pnl  = open_pnl + sum(
        (r.get("realized_pnl") or 0) for r in closed
        if r.get("closed_at", "")[:10] == today_str
    )

    wins      = [r for r in closed if (r.get("realized_pnl") or 0) > 0]
    losses    = [r for r in closed if (r.get("realized_pnl") or 0) <= 0]
    total     = len(closed)
    win_rate  = (len(wins) / total * 100) if total > 0 else 0.0
    avg_win   = (sum(r["realized_pnl"] for r in wins) / len(wins)) if wins else 0.0
    avg_loss  = (sum(abs(r["realized_pnl"]) for r in losses) / len(losses)) if losses else 0.0

    streak = 0
    for r in closed:
        if (r.get("realized_pnl") or 0) > 0:
            streak += 1
        else:
            break

    running = start_balance
    curve = [running]
    for r in reversed(closed):
        running += (r.get("realized_pnl") or 0)
        curve.append(running)
    curve.append(equity)

    return {
        "open_trades":   open_trades,
        "trade_history": history,
        "stats": {
            "equity":       round(equity, 2),
            "balance":      round(start_balance + closed_pnl, 2),
            "daily_pnl":    round(daily_pnl, 2),
            "win_rate":     round(win_rate, 2),
            "avg_win":      round(avg_win, 2),
            "avg_loss":     round(avg_loss, 2),
            "win_streak":   streak,
            "equity_curve": [round(v, 2) for v in curve],
        }
    }


# ─── Mark-to-market update ────────────────────────────────────────────────────

@router.post("/mark-to-market")
@limiter.limit("60/minute")
async def mark_to_market(
    request: Request,
    body: dict = Body(...),
    current_user=Depends(get_current_user)
):
    """
    Update unrealized P&L for all open trades using current prices.
    Maps to PortfolioProvider.markToMarket(prices).

    Body: { "prices": { "EUR/USD": 1.0850, "GBP/JPY": 191.20 } }
    """
    uid = str(current_user["uid"])
    prices: dict = body.get("prices", {})

    open_rows = supabase.table("paper_trades") \
        .select("id, pair, direction, entry_price, lot_size") \
        .eq("user_id", uid).eq("status", "open").execute()

    updated = 0
    for r in (open_rows.data or []):
        pair  = r["pair"]
        price = prices.get(pair)
        if price is None:
            continue

        entry     = float(r["entry_price"])
        lot       = float(r.get("lot_size") or 0.01)
        direction = r["direction"]
        pip_value = lot * 10000
        diff      = (price - entry) if direction == "buy" else (entry - price)
        new_pnl   = diff * pip_value

        supabase.table("paper_trades") \
            .update({"unrealized_pnl": round(new_pnl, 2)}) \
            .eq("id", r["id"]).eq("user_id", uid).execute()
        updated += 1

    return {"updated": updated, "message": f"Updated {updated} open positions"}
