"""
app/services/pepperstone_fix_client.py

Pepperstone FIX API client â€” handles the full FIX 4.4 lifecycle:
  - Persistent SSL TCP connection (price + trade sessions)
  - Logon / Heartbeat / Logout
  - NewOrderSingle (D)  â†’  trade session port 5212
  - MarketDataRequest (V) â†’  price session port 5211
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

from dotenv import load_dotenv
load_dotenv()  # Ensure .env is loaded before os.getenv()

logger = logging.getLogger(__name__)

SOH = "\x01"

TAG = {
    "BeginString": 8, "BodyLength": 9, "MsgType": 35,
    "SenderCompID": 49, "TargetCompID": 56, "SenderSubID": 50, "TargetSubID": 57,
    "MsgSeqNum": 34, "SendingTime": 52, "HeartBtInt": 108,
    "EncryptMethod": 98, "ResetSeqNumFlag": 141, "Password": 554, "Username": 553,
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
        body_fields.append((TAG["TargetSubID"], sender_sub))
    body_fields.extend(fields)
    body = SOH.join(f"{t}={v}" for t, v in body_fields) + SOH
    header = f"{TAG['BeginString']}=FIX.4.4{SOH}{TAG['BodyLength']}={len(body)}{SOH}"
    raw = header + body
    return raw + f"{TAG['CheckSum']}={_checksum(raw)}{SOH}"


class FIXSession:
    def __init__(self, host, port, sender_comp_id, target_comp_id,
                 sender_sub_id, password, username="", use_ssl=True,
                 heartbeat_interval=30, label="fix"):
        self.host = host
        self.port = port
        self.sender = sender_comp_id
        self.target = target_comp_id
        self.sender_sub = sender_sub_id
        self.password = password
        self.username = username
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
            (TAG["Username"], self.username),
            (TAG["Password"], self.password),
        ]
        msg = _build_fix_message(MSG["Logon"], fields, self.sender, self.target,
                                  self._seq_out, self.sender_sub)
        self._seq_out += 1
        await self._send_raw(msg)
        try:
            response = await asyncio.wait_for(self._read_message(), timeout=10)
            logger.info("[%s] Logon raw response: %s", self.label, response)
            if response.get("35") == MSG["Logon"]:
                self._logged_on = True
                logger.info("[%s] Logon accepted", self.label)
                self._recv_task = asyncio.create_task(self._recv_loop())
                self._hb_task = asyncio.create_task(self._heartbeat_loop())
                return True
            logger.error("[%s] Logon rejected â€” got 35=%s", self.label, response.get("35"))
            return False
        except asyncio.TimeoutError:
            logger.error("[%s] Logon timed out â€” no response from server", self.label)
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
            if b"10=" in buf and buf.strip().endswith(b"\x01"):
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
        sym_fields = [(TAG["NoRelatedSym"], str(len(symbols)))]
        for sym in symbols:
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
            password=password, username=account_id, use_ssl=use_ssl, label="TRADE",
        )
        self.price_session = FIXSession(
            host=os.getenv("PEPPERSTONE_PRICE_HOST", "demo-us-eqx-01.p.ctrader.com"),
            port=int(os.getenv("PEPPERSTONE_PRICE_PORT_SSL", "5211")),
            sender_comp_id=os.getenv("PEPPERSTONE_PRICE_SENDER_COMP_ID",
                                      f"demo.pepperstone.{account_id}"),
            target_comp_id=os.getenv("PEPPERSTONE_PRICE_TARGET_COMP_ID", "cServer"),
            sender_sub_id=os.getenv("PEPPERSTONE_PRICE_SENDER_SUB_ID", "QUOTE"),
            password=password, username=account_id, use_ssl=use_ssl, label="PRICE",
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
        logger.info("Pepperstone FIX ready â€” trade=%s price=%s",
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
