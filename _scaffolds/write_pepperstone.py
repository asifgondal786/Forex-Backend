"""
write_pepperstone.py
Run from D:\Tajir\Backend:  python write_pepperstone.py
Writes 3 files into the correct project locations.
"""
import os, sys

FILES = {}

# ── FILE 1: pepperstone_fix_client.py ────────────────────────────────────────
FILES["app/services/pepperstone_fix_client.py"] = r'''"""
app/services/pepperstone_fix_client.py

Pepperstone FIX API client — handles the full FIX 4.4 lifecycle:
  - Persistent SSL TCP connection (price + trade sessions)
  - Logon / Heartbeat / Logout
  - NewOrderSingle (D)  →  trade session port 5212
  - MarketDataRequest (V) →  price session port 5211
  - OrderCancelRequest (F)

Environment variables consumed (all in your .env already):
  PEPPERSTONE_ACCOUNT_ID
  PEPPERSTONE_PASSWORD
  PEPPERSTONE_PRICE_HOST / PEPPERSTONE_PRICE_PORT_SSL
  PEPPERSTONE_TRADE_HOST / PEPPERSTONE_TRADE_PORT_SSL
  PEPPERSTONE_PRICE_SENDER_COMP_ID / PEPPERSTONE_PRICE_TARGET_COMP_ID
  PEPPERSTONE_TRADE_SENDER_COMP_ID / PEPPERSTONE_TRADE_TARGET_COMP_ID
  USE_SSL_FIX
"""
from __future__ import annotations

import asyncio
import logging
import os
import ssl
import uuid
from datetime import datetime, timezone
from typing import Dict, List, Optional

logger = logging.getLogger(__name__)

SOH = "\x01"

TAG = {
    "BeginString": 8, "BodyLength": 9, "MsgType": 35,
    "SenderCompID": 49, "TargetCompID": 56, "SenderSubID": 50,
    "MsgSeqNum": 34, "SendingTime": 52, "HeartBtInt": 108,
    "EncryptMethod": 98, "ResetSeqNumFlag": 141, "Password": 554,
    "CheckSum": 10, "ClOrdID": 11, "Symbol": 55, "Side": 54,
    "TransactTime": 60, "OrdType": 40, "OrderQty": 38,
    "StopPx": 99, "Price": 44, "TimeInForce": 59, "Account": 1,
    "MDReqID": 262, "SubscriptionRequestType": 263,
    "MarketDepth": 264, "MDUpdateType": 265,
    "NoMDEntryTypes": 267, "MDEntryType": 269, "NoRelatedSym": 146,
    "OrigClOrdID": 41, "OrderID": 37,
}

MSG = {
    "Logon": "A", "Logout": "5", "Heartbeat": "0", "TestRequest": "1",
    "NewOrderSingle": "D", "OrderCancelRequest": "F",
    "ExecutionReport": "8", "MarketDataRequest": "V",
    "MarketDataSnapshot": "W", "MarketDataReject": "Y", "Reject": "3",
}

SIDE_BUY = "1"
SIDE_SELL = "2"
ORD_MARKET = "1"
ORD_LIMIT = "2"


def _utcnow() -> str:
    return datetime.now(timezone.utc).strftime("%Y%m%d-%H:%M:%S.%f")[:-3]


def _checksum(raw: str) -> str:
    return f"{sum(ord(c) for c in raw) % 256:03d}"


def _build_fix_message(msg_type, fields, sender, target, seq, sender_sub=""):
    body_fields = [
        (TAG["MsgType"], msg_type), (TAG["SenderCompID"], sender),
        (TAG["TargetCompID"], target), (TAG["MsgSeqNum"], str(seq)),
        (TAG["SendingTime"], _utcnow()),
    ]
    if sender_sub:
        body_fields.append((TAG["SenderSubID"], sender_sub))
    body_fields.extend(fields)
    body = SOH.join(f"{t}={v}" for t, v in body_fields) + SOH
    header = f"{TAG['BeginString']}=FIX.4.4{SOH}{TAG['BodyLength']}={len(body)}{SOH}"
    raw = header + body
    return raw + f"{TAG['CheckSum']}={_checksum(raw)}{SOH}"


class FIXSession:
    def __init__(self, host, port, sender_comp_id, target_comp_id,
                 sender_sub_id, password, use_ssl=True,
                 heartbeat_interval=30, label="fix"):
        self.host = host
        self.port = port
        self.sender = sender_comp_id
        self.target = target_comp_id
        self.sender_sub = sender_sub_id
        self.password = password
        self.use_ssl = use_ssl
        self.hb_interval = heartbeat_interval
        self.label = label
        self._reader = None
        self._writer = None
        self._seq_out = 1
        self._logged_on = False
        self._pending: Dict[str, asyncio.Future] = {}
        self._last_prices: Dict[str, Dict] = {}
        self._lock = asyncio.Lock()
        self._hb_task = None
        self._recv_task = None

    async def connect(self) -> bool:
        try:
            if self.use_ssl:
                ctx = ssl.create_default_context()
                ctx.check_hostname = False
                ctx.verify_mode = ssl.CERT_NONE
                self._reader, self._writer = await asyncio.open_connection(
                    self.host, self.port, ssl=ctx)
            else:
                self._reader, self._writer = await asyncio.open_connection(
                    self.host, self.port)
            logger.info("[%s] TCP connected to %s:%s", self.label, self.host, self.port)
            return True
        except Exception as exc:
            logger.error("[%s] TCP connect failed: %s", self.label, exc)
            return False

    async def logon(self) -> bool:
        fields = [
            (TAG["EncryptMethod"], "0"),
            (TAG["HeartBtInt"], str(self.hb_interval)),
            (TAG["ResetSeqNumFlag"], "Y"),
            (TAG["Password"], self.password),
        ]
        msg = _build_fix_message(MSG["Logon"], fields, self.sender, self.target,
                                  self._seq_out, self.sender_sub)
        self._seq_out += 1
        await self._send_raw(msg)
        try:
            response = await asyncio.wait_for(self._read_message(), timeout=10)
            if response.get("35") == MSG["Logon"]:
                self._logged_on = True
                logger.info("[%s] Logon accepted", self.label)
                self._recv_task = asyncio.create_task(self._recv_loop())
                self._hb_task = asyncio.create_task(self._heartbeat_loop())
                return True
            return False
        except asyncio.TimeoutError:
            logger.error("[%s] Logon timed out", self.label)
            return False

    async def logout(self) -> None:
        if not self._logged_on:
            return
        msg = _build_fix_message(MSG["Logout"], [], self.sender, self.target,
                                  self._seq_out, self.sender_sub)
        self._seq_out += 1
        await self._send_raw(msg)
        self._logged_on = False
        if self._hb_task:
            self._hb_task.cancel()
        if self._recv_task:
            self._recv_task.cancel()
        if self._writer:
            self._writer.close()
        logger.info("[%s] Logged out", self.label)

    async def _send_raw(self, msg: str) -> None:
        async with self._lock:
            if self._writer:
                self._writer.write(msg.encode("ascii"))
                await self._writer.drain()

    async def _read_message(self) -> Dict[str, str]:
        buf = b""
        while self._reader:
            chunk = await self._reader.read(4096)
            if not chunk:
                break
            buf += chunk
            if b"\x01" in buf:
                return self._parse_fix(buf.decode("ascii", errors="replace"))
        return {}

    def _parse_fix(self, raw: str) -> Dict[str, str]:
        fields = {}
        for part in raw.split(SOH):
            if "=" in part:
                tag, _, val = part.partition("=")
                fields[tag.strip()] = val.strip()
        return fields

    async def _heartbeat_loop(self) -> None:
        while self._logged_on:
            await asyncio.sleep(self.hb_interval)
            if not self._logged_on:
                break
            msg = _build_fix_message(MSG["Heartbeat"], [], self.sender,
                                      self.target, self._seq_out, self.sender_sub)
            self._seq_out += 1
            await self._send_raw(msg)

    async def _recv_loop(self) -> None:
        buf = b""
        while self._logged_on and self._reader:
            try:
                chunk = await asyncio.wait_for(self._reader.read(4096), timeout=60)
                if not chunk:
                    break
                buf += chunk
                while b"10=" in buf and buf.endswith(b"\x01"):
                    fields = self._parse_fix(buf.decode("ascii", errors="replace"))
                    await self._dispatch(fields)
                    buf = b""
            except asyncio.TimeoutError:
                continue
            except Exception as exc:
                logger.error("[%s] Recv loop error: %s", self.label, exc)
                break

    async def _dispatch(self, fields: Dict[str, str]) -> None:
        msg_type = fields.get("35", "")
        if msg_type == MSG["Heartbeat"]:
            return
        if msg_type == MSG["TestRequest"]:
            test_req_id = fields.get("112", "")
            hb = _build_fix_message(MSG["Heartbeat"], [(112, test_req_id)],
                                     self.sender, self.target,
                                     self._seq_out, self.sender_sub)
            self._seq_out += 1
            await self._send_raw(hb)
        elif msg_type == MSG["ExecutionReport"]:
            cl_ord_id = fields.get("11", "")
            if cl_ord_id in self._pending:
                fut = self._pending.pop(cl_ord_id)
                if not fut.done():
                    fut.set_result(fields)
        elif msg_type == MSG["MarketDataSnapshot"]:
            symbol = fields.get("55", "")
            if symbol:
                self._last_prices[symbol] = {
                    "bid": fields.get("270", ""),
                    "ask": fields.get("271", ""),
                    "timestamp": _utcnow(),
                }
        elif msg_type == MSG["Reject"]:
            logger.warning("[%s] FIX Reject: %s", self.label, fields)

    async def send_new_order(self, symbol, side, quantity, account_id,
                              order_type="market", price=None,
                              stop_loss=None, take_profit=None,
                              timeout=15.0) -> Dict:
        if not self._logged_on:
            return {"success": False, "error": "FIX session not logged on"}

        cl_ord_id = f"PS{uuid.uuid4().hex[:14].upper()}"
        fix_side = SIDE_BUY if side.lower() == "buy" else SIDE_SELL
        fix_type = ORD_MARKET if order_type.lower() == "market" else ORD_LIMIT

        fields = [
            (TAG["ClOrdID"], cl_ord_id),
            (TAG["Account"], account_id),
            (TAG["Symbol"], symbol.replace("/", "")),
            (TAG["Side"], fix_side),
            (TAG["TransactTime"], _utcnow()),
            (TAG["OrdType"], fix_type),
            (TAG["OrderQty"], str(quantity)),
        ]
        if price and fix_type != ORD_MARKET:
            fields.append((TAG["Price"], str(price)))
        if stop_loss:
            fields.append((TAG["StopPx"], str(stop_loss)))

        msg = _build_fix_message(MSG["NewOrderSingle"], fields, self.sender,
                                  self.target, self._seq_out, self.sender_sub)
        self._seq_out += 1

        loop = asyncio.get_event_loop()
        fut = loop.create_future()
        self._pending[cl_ord_id] = fut
        await self._send_raw(msg)

        try:
            exec_report = await asyncio.wait_for(fut, timeout=timeout)
            return {
                "success": True,
                "broker": "Pepperstone",
                "cl_ord_id": cl_ord_id,
                "broker_order_id": exec_report.get("37", cl_ord_id),
                "status": _ord_status_label(exec_report.get("39", "?")),
                "executed_price": exec_report.get("31", exec_report.get("44", "")),
                "executed_at": _utcnow(),
                "execution_mode": "live_fix",
                "raw": exec_report,
            }
        except asyncio.TimeoutError:
            self._pending.pop(cl_ord_id, None)
            return {"success": False,
                    "error": f"Execution report not received within {timeout}s",
                    "broker": "Pepperstone", "cl_ord_id": cl_ord_id}

    async def subscribe_market_data(self, symbols: List[str]) -> None:
        if not self._logged_on:
            return
        req_id = f"MD{uuid.uuid4().hex[:8].upper()}"
        sym_fields = []
        for sym in symbols:
            sym_fields.append((TAG["NoRelatedSym"], str(len(symbols))))
            sym_fields.append((55, sym.replace("/", "")))
        fields = [
            (TAG["MDReqID"], req_id),
            (TAG["SubscriptionRequestType"], "1"),
            (TAG["MarketDepth"], "1"),
            (TAG["MDUpdateType"], "0"),
            (TAG["NoMDEntryTypes"], "2"),
            (TAG["MDEntryType"], "0"),
            (TAG["MDEntryType"], "1"),
        ] + sym_fields
        msg = _build_fix_message(MSG["MarketDataRequest"], fields, self.sender,
                                  self.target, self._seq_out, self.sender_sub)
        self._seq_out += 1
        await self._send_raw(msg)
        logger.info("[%s] Subscribed market data: %s", self.label, symbols)

    def get_last_price(self, symbol: str) -> Optional[Dict]:
        return self._last_prices.get(symbol.replace("/", ""))

    @property
    def is_connected(self) -> bool:
        return self._logged_on


def _ord_status_label(code: str) -> str:
    return {"0": "new", "1": "partially_filled", "2": "filled",
            "4": "cancelled", "8": "rejected", "A": "pending_new"}.get(
        code, f"unknown_{code}")


class PepperstoneFixManager:
    def __init__(self) -> None:
        use_ssl = os.getenv("USE_SSL_FIX", "true").lower() == "true"
        password = os.getenv("PEPPERSTONE_PASSWORD", "")
        account_id = os.getenv("PEPPERSTONE_ACCOUNT_ID", "")
        self.account_id = account_id

        self.trade_session = FIXSession(
            host=os.getenv("PEPPERSTONE_TRADE_HOST", "demo-us-eqx-01.p.ctrader.com"),
            port=int(os.getenv("PEPPERSTONE_TRADE_PORT_SSL", "5212")),
            sender_comp_id=os.getenv("PEPPERSTONE_TRADE_SENDER_COMP_ID",
                                      f"demo.pepperstone.{account_id}"),
            target_comp_id=os.getenv("PEPPERSTONE_TRADE_TARGET_COMP_ID", "cServer"),
            sender_sub_id=os.getenv("PEPPERSTONE_TRADE_SENDER_SUB_ID", "TRADE"),
            password=password, use_ssl=use_ssl, label="TRADE",
        )
        self.price_session = FIXSession(
            host=os.getenv("PEPPERSTONE_PRICE_HOST", "demo-us-eqx-01.p.ctrader.com"),
            port=int(os.getenv("PEPPERSTONE_PRICE_PORT_SSL", "5211")),
            sender_comp_id=os.getenv("PEPPERSTONE_PRICE_SENDER_COMP_ID",
                                      f"demo.pepperstone.{account_id}"),
            target_comp_id=os.getenv("PEPPERSTONE_PRICE_TARGET_COMP_ID", "cServer"),
            sender_sub_id=os.getenv("PEPPERSTONE_PRICE_SENDER_SUB_ID", "QUOTE"),
            password=password, use_ssl=use_ssl, label="PRICE",
        )
        self._started = False

    async def startup(self, subscribe_symbols=None) -> None:
        if self._started:
            return
        ok_trade = await self.trade_session.connect()
        if ok_trade:
            await self.trade_session.logon()
        ok_price = await self.price_session.connect()
        if ok_price:
            await self.price_session.logon()
            if subscribe_symbols:
                await asyncio.sleep(1)
                await self.price_session.subscribe_market_data(subscribe_symbols)
        self._started = True
        logger.info("Pepperstone FIX ready — trade=%s price=%s",
                    self.trade_session.is_connected, self.price_session.is_connected)

    async def shutdown(self) -> None:
        await self.trade_session.logout()
        await self.price_session.logout()
        self._started = False

    async def execute_order(self, symbol, side, quantity, order_type="market",
                             price=None, stop_loss=None, take_profit=None) -> Dict:
        return await self.trade_session.send_new_order(
            symbol=symbol, side=side, quantity=quantity,
            account_id=self.account_id, order_type=order_type,
            price=price, stop_loss=stop_loss, take_profit=take_profit,
        )

    def get_price(self, symbol: str) -> Optional[Dict]:
        return self.price_session.get_last_price(symbol)

    @property
    def trade_ready(self) -> bool:
        return self.trade_session.is_connected

    @property
    def price_ready(self) -> bool:
        return self.price_session.is_connected


pepperstone = PepperstoneFixManager()
'''

# ── FILE 2: broker_execution_service.py ──────────────────────────────────────
FILES["app/services/broker_execution_service.py"] = r'''"""
Broker Execution Service
Centralizes broker account bindings and broker-side execution handoff.
Now wired to Pepperstone via FIX API.
"""
from __future__ import annotations
from datetime import datetime
from typing import Dict, List, Optional, Tuple
import os, uuid, logging

from app.services.pepperstone_fix_client import pepperstone

logger = logging.getLogger(__name__)
BROKER_NAME = "Pepperstone"


class BrokerExecutionService:
    def __init__(self) -> None:
        self._connections_by_user: Dict[str, List[Dict]] = {}
        self._bootstrap_dev_connection("dev_user_001")

    def _bootstrap_dev_connection(self, user_id: str) -> None:
        if user_id in self._connections_by_user and self._connections_by_user[user_id]:
            return
        account_id = os.getenv("PEPPERSTONE_ACCOUNT_ID", "5272744")
        self._connections_by_user[user_id] = [{
            "id": f"ps_{account_id}", "broker": BROKER_NAME,
            "account_number": account_id, "balance": 10_000.0,
            "currency": "USD", "status": "connected",
            "last_updated": "2026-04-22T00:00:00Z",
            "mode": self._default_account_mode(),
        }]

    def _ensure_user_connections(self, user_id: str) -> List[Dict]:
        if user_id not in self._connections_by_user:
            self._connections_by_user[user_id] = []
        if user_id.startswith("dev_") and not self._connections_by_user[user_id]:
            self._bootstrap_dev_connection(user_id)
        return self._connections_by_user[user_id]

    def get_account_connections(self, user_id: str) -> List[Dict]:
        return list(self._ensure_user_connections(user_id))

    def _default_account_mode(self) -> str:
        mode = os.getenv("PEPPERSTONE_DEFAULT_ACCOUNT_MODE", "demo").strip().lower()
        return "live" if mode == "live" else "demo"

    def infer_account_mode(self, username: str) -> str:
        lowered = (username or "").strip().lower()
        if lowered.startswith("live_"):
            return "live"
        if lowered.startswith("demo_"):
            return "demo"
        return self._default_account_mode()

    def connect_broker_account(self, user_id: str, account_number: str, password: str) -> Dict:
        if not account_number or not password:
            raise ValueError("Account number and password are required")
        connections = self._ensure_user_connections(user_id)
        for conn in connections:
            if conn.get("account_number") == account_number:
                conn["status"] = "connected"
                conn["last_updated"] = datetime.now().isoformat()
                return conn
        connection = {
            "id": f"ps_{account_number}", "broker": BROKER_NAME,
            "account_number": account_number, "balance": 0.0, "currency": "USD",
            "status": "connected", "last_updated": datetime.now().isoformat(),
            "mode": self.infer_account_mode(account_number),
        }
        connections.append(connection)
        logger.info("Pepperstone account %s connected for user %s", account_number, user_id)
        return connection

    # Alias so existing routes don't break
    def connect_forex_account(self, user_id: str, username: str, password: str) -> Dict:
        return self.connect_broker_account(user_id, username, password)

    def disconnect_account(self, user_id: str, account_id: str) -> bool:
        connections = self._ensure_user_connections(user_id)
        before = len(connections)
        self._connections_by_user[user_id] = [
            c for c in connections if c.get("id") != account_id]
        return len(self._connections_by_user[user_id]) < before

    def get_account_balance(self, user_id: str, account_id: str) -> Optional[Tuple[float, str]]:
        for conn in self._ensure_user_connections(user_id):
            if conn.get("id") == account_id and conn.get("status") == "connected":
                return float(conn.get("balance", 0.0)), str(conn.get("currency", "USD"))
        return None

    def _select_connected_account(self, user_id: str, account_id: Optional[str]) -> Optional[Dict]:
        connected = [c for c in self._ensure_user_connections(user_id)
                     if c.get("status") == "connected"]
        if not connected:
            return None
        if account_id:
            for conn in connected:
                if conn.get("id") == account_id:
                    return conn
            return None
        return connected[0]

    def _is_live_execution_enabled(self) -> bool:
        return os.getenv("PEPPERSTONE_LIVE_EXECUTION", "false").lower() == "true"

    async def _execute_via_fix(self, trade_params: Dict, account: Dict) -> Dict:
        if not pepperstone.trade_ready:
            logger.warning("FIX trade session not connected — falling back to simulation")
            return self._simulated_result(trade_params, account, reason="fix_not_connected")
        result = await pepperstone.execute_order(
            symbol=str(trade_params.get("pair", "")).replace("/", ""),
            side=str(trade_params.get("action", "")).lower(),
            quantity=float(trade_params.get("position_size", 0.01) or 0.01),
            order_type="market",
            price=float(p) if (p := trade_params.get("entry_price")) else None,
            stop_loss=float(sl) if (sl := trade_params.get("stop_loss")) else None,
            take_profit=float(tp) if (tp := trade_params.get("take_profit")) else None,
        )
        result["account_id"] = account.get("id")
        result["account_number"] = account.get("account_number")
        return result

    def _simulated_result(self, trade_params: Dict, account: Dict, reason: str = "demo_mode") -> Dict:
        return {
            "success": True, "broker": BROKER_NAME,
            "account_id": account.get("id"),
            "account_number": account.get("account_number"),
            "broker_order_id": f"ps_sim_{uuid.uuid4().hex[:14]}",
            "status": "filled", "execution_mode": "simulated",
            "simulation_reason": reason,
            "executed_at": datetime.now().isoformat(),
            "executed_price": trade_params.get("entry_price"),
            "message": f"Order simulated ({reason}) — no real trade sent to Pepperstone.",
        }

    async def execute_trade(self, user_id: str, trade_params: Dict) -> Dict:
        account = self._select_connected_account(
            user_id, str(trade_params.get("account_id") or "").strip() or None)
        if not account:
            return {"success": False,
                    "error": "No connected Pepperstone account available",
                    "requires_account_connection": True}

        broker = str(account.get("broker", "")).lower()
        if broker not in {"pepperstone", ""}:
            return {"success": False,
                    "error": f"Account broker '{broker}' is not Pepperstone",
                    "account_id": account.get("id")}

        account_mode = str(account.get("mode", "demo")).lower()
        if self._is_live_execution_enabled() and account_mode == "live":
            return await self._execute_via_fix(trade_params, account)

        reason = "live_execution_disabled" if account_mode == "live" else "demo_account"
        return self._simulated_result(trade_params, account, reason=reason)


broker_execution_service = BrokerExecutionService()
'''

# ── FILE 3: risk_guardian_bridge.py ──────────────────────────────────────────
FILES["app/risk_guardian_bridge.py"] = r'''"""
Tajir AI Risk Guardian — FastAPI Route + Middleware
Phase 17 — Updated: live spread from Pepperstone FIX price session.
"""
from fastapi import APIRouter, HTTPException, Depends, status
from pydantic import BaseModel
from typing import Optional
import logging

from app.risk.risk_models import (
    TradeRequest, AccountSnapshot, MarketSnapshot,
    RiskGuardianResult, RiskDecision,
)
from app.risk.risk_guardian import evaluate_trade
from app.services.pepperstone_fix_client import pepperstone

logger = logging.getLogger("risk_guardian")
risk_router = APIRouter(tags=["Risk Guardian"])


class GuardianCheckRequest(BaseModel):
    trade:   TradeRequest
    account: AccountSnapshot
    market:  MarketSnapshot


class GuardianCheckResponse(BaseModel):
    result:  RiskGuardianResult
    blocked: bool
    message: str


async def get_account_snapshot(user_id: str) -> AccountSnapshot:
    # TODO - replace with Supabase query
    return AccountSnapshot(
        balance=10_000.0, equity=9_800.0, current_drawdown_pct=2.0,
        daily_loss_pct=0.5, open_positions=2, win_rate_7d=55.0,
        consecutive_losses=1,
    )


async def get_market_snapshot(symbol: str) -> MarketSnapshot:
    """Pulls live spread from Pepperstone FIX price feed. Falls back to safe defaults."""
    price_data = pepperstone.get_price(symbol)
    spread_pips = 1.5   # safe default
    if price_data:
        try:
            bid = float(price_data.get("bid") or 0)
            ask = float(price_data.get("ask") or 0)
            if bid and ask:
                spread_pips = round((ask - bid) * 10_000, 1)
        except (ValueError, TypeError):
            pass
    return MarketSnapshot(
        symbol=symbol,
        current_spread_pips=spread_pips,
        atr_14=8.0,             # TODO: wire from technical_analysis_service
        is_news_window=False,   # TODO: wire from macro_event_service
        session="london",       # TODO: wire from session detector
        volatility_index=35.0,
    )


@risk_router.post("/risk/check", response_model=GuardianCheckResponse)
async def check_risk(body: GuardianCheckRequest):
    result = evaluate_trade(body.trade, body.account, body.market)
    return GuardianCheckResponse(result=result, blocked=not result.approved,
                                  message=result.explanation)


@risk_router.post("/risk/check-trade/{user_id}", response_model=GuardianCheckResponse)
async def check_trade_for_user(user_id: str, trade: TradeRequest):
    account = await get_account_snapshot(user_id)
    market  = await get_market_snapshot(trade.symbol)
    result  = evaluate_trade(trade, account, market)
    if result.decision == RiskDecision.BLOCK:
        logger.warning("BLOCKED trade user=%s symbol=%s score=%.1f",
                       user_id, trade.symbol, result.composite_score)
    return GuardianCheckResponse(result=result, blocked=not result.approved,
                                  message=result.explanation)


class AuditLogEntry(BaseModel):
    user_id: str; symbol: str; decision: RiskDecision
    composite_score: float; explanation: str; hard_limits_hit: list[str]


@risk_router.get("/risk/audit/{user_id}", response_model=list[AuditLogEntry])
async def get_audit_log(user_id: str, limit: int = 20):
    return []  # TODO: Supabase query


async def guard_trade(user_id: str, trade: TradeRequest) -> RiskGuardianResult:
    account = await get_account_snapshot(user_id)
    market  = await get_market_snapshot(trade.symbol)
    return evaluate_trade(trade, account, market)
'''

# ── Write all files ───────────────────────────────────────────────────────────
BASE = os.path.dirname(os.path.abspath(__file__))
errors = []

for rel_path, content in FILES.items():
    abs_path = os.path.join(BASE, rel_path.replace("/", os.sep))
    os.makedirs(os.path.dirname(abs_path), exist_ok=True)
    try:
        with open(abs_path, "w", encoding="utf-8") as f:
            f.write(content.lstrip("\n"))
        line_count = content.count("\n")
        print(f"[OK] Written: {rel_path}  ({line_count} lines)")
    except Exception as e:
        print(f"[FAIL] {rel_path}: {e}")
        errors.append(rel_path)

print()
if errors:
    print(f"[WARN] {len(errors)} file(s) failed to write.")
else:
    print("[DONE] All 3 files written successfully.")
    print()
    print("Next steps:")
    print("1. Add pepperstone.startup() to your app lifespan in main.py")
    print("2. Add PEPPERSTONE_LIVE_EXECUTION=false to .env (keep false for demo testing)")
    print("3. Run: uvicorn app.main:app --reload")
    print("4. Check logs for: 'Pepperstone FIX ready — trade=True price=True'")
