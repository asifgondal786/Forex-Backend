"""
Pepperstone FIX API Trading Service
Tajir Forex Companion — pepper_trading_service.py

Deploy to: /home/opc/Forex-Backend/Backend/Backend/Backend/app/services/pepper_trading_service.py

FIX Protocol 4.4 implementation for:
  - Price subscriptions (MarketDataRequest)
  - Order execution (NewOrderSingle)
  - Position / account queries (RequestForPositions, CollateralInquiry)

Credentials are read from environment variables set in /etc/forex-backend/.env
"""

import asyncio
import logging
import os
import socket
import ssl
import time
import threading
from datetime import datetime, timezone
from decimal import Decimal
from typing import Callable, Dict, List, Optional

logger = logging.getLogger(__name__)


# ---------------------------------------------------------------------------
# Environment / Config
# ---------------------------------------------------------------------------

class PepperstoneConfig:
    """Reads all Pepperstone FIX credentials from environment."""

    # Price feed connection
    PRICE_HOST: str = os.getenv("PEPPERSTONE_PRICE_HOST", "")
    PRICE_PORT: int = int(os.getenv("PEPPERSTONE_PRICE_PORT_SSL", "5201"))
    PRICE_SENDER_COMP_ID: str = os.getenv("PEPPERSTONE_PRICE_SENDER_COMP_ID", "")

    # Trade connection (may share host or have separate)
    TRADE_HOST: str = os.getenv("PEPPERSTONE_TRADE_HOST", os.getenv("PEPPERSTONE_PRICE_HOST", ""))
    TRADE_PORT: int = int(os.getenv("PEPPERSTONE_TRADE_PORT_SSL", "5202"))
    TRADE_SENDER_COMP_ID: str = os.getenv("PEPPERSTONE_TRADE_SENDER_COMP_ID", os.getenv("PEPPERSTONE_PRICE_SENDER_COMP_ID", ""))

    # Account credentials
    ACCOUNT_ID: str = os.getenv("PEPPERSTONE_ACCOUNT_ID", "")
    PASSWORD: str = os.getenv("PEPPERSTONE_PASSWORD", "")

    # Target comp IDs (Pepperstone counterparty)
    PRICE_TARGET_COMP_ID: str = os.getenv("PEPPERSTONE_PRICE_TARGET_COMP_ID", "PEPPERSTONE-PRICES")
    TRADE_TARGET_COMP_ID: str = os.getenv("PEPPERSTONE_TRADE_TARGET_COMP_ID", "PEPPERSTONE")

    # FIX settings
    FIX_VERSION: str = "FIX.4.4"
    HEARTBEAT_INTERVAL: int = int(os.getenv("PEPPERSTONE_HEARTBEAT_INTERVAL", "30"))

    @classmethod
    def validate(cls) -> List[str]:
        """Return list of missing required env vars."""
        missing = []
        for field in ["PRICE_HOST", "PRICE_SENDER_COMP_ID", "ACCOUNT_ID", "PASSWORD"]:
            if not getattr(cls, field):
                missing.append(f"PEPPERSTONE_{field}")
        return missing


# ---------------------------------------------------------------------------
# FIX Message Builder / Parser
# ---------------------------------------------------------------------------

SOH = "\x01"  # FIX field delimiter


def fix_field(tag: int, value) -> str:
    return f"{tag}={value}{SOH}"


def build_fix_message(msg_type: str, sender: str, target: str, seq_num: int,
                      fields: Dict[int, str]) -> bytes:
    """
    Build a FIX 4.4 message with correct header, body, and checksum.
    Standard header tags: 8, 9, 35, 49, 56, 34, 52
    """
    sending_time = datetime.now(timezone.utc).strftime("%Y%m%d-%H:%M:%S.%f")[:-3]

    body = ""
    body += fix_field(35, msg_type)
    body += fix_field(49, sender)
    body += fix_field(56, target)
    body += fix_field(34, seq_num)
    body += fix_field(52, sending_time)

    for tag in sorted(fields.keys()):
        body += fix_field(tag, fields[tag])

    header = fix_field(8, PepperstoneConfig.FIX_VERSION)
    header += fix_field(9, len(body))

    full_msg = header + body
    checksum = sum(ord(c) for c in full_msg) % 256
    full_msg += fix_field(10, f"{checksum:03d}")

    return full_msg.encode("ascii")


def parse_fix_message(raw: str) -> Dict[str, str]:
    """Parse a FIX message string into a tag→value dict."""
    fields = {}
    for part in raw.split(SOH):
        if "=" in part:
            tag, _, value = part.partition("=")
            fields[tag.strip()] = value.strip()
    return fields


# ---------------------------------------------------------------------------
# SSL FIX Socket Session
# ---------------------------------------------------------------------------

class FIXSession:
    """
    Low-level FIX session over SSL/TLS.
    Handles Logon, Heartbeat, and message dispatch.
    """

    def __init__(self, host: str, port: int, sender: str, target: str,
                 account: str, password: str,
                 on_message: Optional[Callable[[Dict], None]] = None):
        self.host = host
        self.port = port
        self.sender = sender
        self.target = target
        self.account = account
        self.password = password
        self.on_message = on_message

        self._seq_num = 1
        self._sock: Optional[ssl.SSLSocket] = None
        self._connected = False
        self._logged_on = False
        self._lock = threading.Lock()
        self._recv_thread: Optional[threading.Thread] = None
        self._heartbeat_thread: Optional[threading.Thread] = None
        self._buffer = ""

    # ------------------------------------------------------------------
    # Connection lifecycle
    # ------------------------------------------------------------------

    def connect(self, timeout: int = 10) -> bool:
        """Establish SSL TCP connection to FIX endpoint."""
        try:
            ctx = ssl.create_default_context()
            ctx.check_hostname = False
            ctx.verify_mode = ssl.CERT_NONE  # Demo accounts — enable for prod

            raw_sock = socket.create_connection((self.host, self.port), timeout=timeout)
            self._sock = ctx.wrap_socket(raw_sock, server_hostname=self.host)
            self._connected = True
            logger.info(f"FIX TCP connected to {self.host}:{self.port}")
            return True
        except Exception as e:
            logger.error(f"FIX connect failed: {e}")
            self._connected = False
            return False

    def logon(self) -> bool:
        """Send FIX Logon (35=A) message."""
        if not self._connected:
            return False

        fields = {
            98: "0",                                  # EncryptMethod: None
            108: str(PepperstoneConfig.HEARTBEAT_INTERVAL),  # HeartBtInt
            553: self.account,                        # Username
            554: self.password,                       # Password
            141: "Y",                                 # ResetSeqNumFlag
        }
        msg = build_fix_message("A", self.sender, self.target, self._seq_num, fields)
        self._seq_num += 1

        try:
            self._sock.sendall(msg)
            logger.info("FIX Logon sent")

            # Start receive loop and heartbeat
            self._recv_thread = threading.Thread(target=self._recv_loop, daemon=True)
            self._recv_thread.start()
            self._heartbeat_thread = threading.Thread(target=self._heartbeat_loop, daemon=True)
            self._heartbeat_thread.start()
            return True
        except Exception as e:
            logger.error(f"FIX Logon send failed: {e}")
            return False

    def logout(self):
        """Send Logout (35=5) and close connection."""
        if self._connected and self._logged_on:
            try:
                msg = build_fix_message("5", self.sender, self.target, self._seq_num, {})
                self._seq_num += 1
                self._sock.sendall(msg)
            except Exception:
                pass
        self._connected = False
        self._logged_on = False
        if self._sock:
            try:
                self._sock.close()
            except Exception:
                pass
        logger.info("FIX session closed")

    # ------------------------------------------------------------------
    # Send / receive
    # ------------------------------------------------------------------

    def send(self, msg_type: str, fields: Dict[int, str]) -> bool:
        """Send any FIX message."""
        if not self._connected:
            logger.warning("FIX send attempted while disconnected")
            return False
        with self._lock:
            msg = build_fix_message(msg_type, self.sender, self.target, self._seq_num, fields)
            self._seq_num += 1
        try:
            self._sock.sendall(msg)
            return True
        except Exception as e:
            logger.error(f"FIX send error: {e}")
            self._connected = False
            return False

    def _recv_loop(self):
        """Background thread — reads raw bytes and dispatches parsed messages."""
        while self._connected:
            try:
                chunk = self._sock.recv(4096)
                if not chunk:
                    logger.warning("FIX connection closed by peer")
                    self._connected = False
                    break
                self._buffer += chunk.decode("ascii", errors="ignore")
                self._process_buffer()
            except ssl.SSLError:
                break
            except Exception as e:
                if self._connected:
                    logger.error(f"FIX recv error: {e}")
                break

    def _process_buffer(self):
        """Extract complete FIX messages from buffer and dispatch."""
        while True:
            start = self._buffer.find("8=FIX")
            if start == -1:
                self._buffer = ""
                break
            # Find checksum trailer
            end = self._buffer.find(f"10=", start)
            if end == -1:
                break
            end = self._buffer.find(SOH, end)
            if end == -1:
                break
            raw_msg = self._buffer[start:end + 1]
            self._buffer = self._buffer[end + 1:]
            parsed = parse_fix_message(raw_msg)
            self._dispatch(parsed)

    def _dispatch(self, msg: Dict[str, str]):
        """Handle standard session-level messages; forward app messages."""
        msg_type = msg.get("35", "")

        if msg_type == "A":  # Logon ack
            self._logged_on = True
            logger.info("FIX Logon acknowledged")
        elif msg_type == "5":  # Logout
            self._logged_on = False
            self._connected = False
            logger.info("FIX Logout received")
        elif msg_type == "0":  # Heartbeat
            pass  # just ACK
        elif msg_type == "1":  # TestRequest — must reply with Heartbeat
            test_req_id = msg.get("112", "")
            self.send("0", {112: test_req_id})
        elif msg_type == "3":  # Reject
            logger.warning(f"FIX Reject received: {msg}")
        else:
            if self.on_message:
                try:
                    self.on_message(msg)
                except Exception as e:
                    logger.error(f"FIX message handler error: {e}")

    def _heartbeat_loop(self):
        """Send Heartbeat (35=0) every HeartBtInt seconds."""
        interval = PepperstoneConfig.HEARTBEAT_INTERVAL
        while self._connected:
            time.sleep(interval)
            if self._connected and self._logged_on:
                self.send("0", {})


# ---------------------------------------------------------------------------
# Price Feed
# ---------------------------------------------------------------------------

class PepperPriceFeed:
    """
    Subscribes to market data for one or more FX pairs via FIX MarketDataRequest.
    Maintains an in-memory cache of latest bid/ask prices.
    """

    SUPPORTED_PAIRS = [
        "EUR/USD", "GBP/USD", "USD/JPY", "AUD/USD", "USD/CAD",
        "NZD/USD", "EUR/GBP", "EUR/JPY", "GBP/JPY", "USD/CHF",
    ]

    def __init__(self):
        cfg = PepperstoneConfig
        self._session = FIXSession(
            host=cfg.PRICE_HOST,
            port=cfg.PRICE_PORT,
            sender=cfg.PRICE_SENDER_COMP_ID,
            target=cfg.PRICE_TARGET_COMP_ID,
            account=cfg.ACCOUNT_ID,
            password=cfg.PASSWORD,
            on_message=self._on_price_message,
        )
        self._prices: Dict[str, Dict] = {}
        self._req_id = 1
        self._connected = False

    def start(self) -> bool:
        """Connect and logon to price feed."""
        missing = PepperstoneConfig.validate()
        if missing:
            logger.error(f"Missing env vars: {missing}")
            return False

        if not self._session.connect():
            return False
        if not self._session.logon():
            return False

        # Wait for logon ack (up to 5s)
        for _ in range(50):
            if self._session._logged_on:
                self._connected = True
                logger.info("Pepper price feed connected and logged on")
                return True
            time.sleep(0.1)

        logger.error("Pepper logon timeout")
        return False

    def stop(self):
        self._session.logout()
        self._connected = False

    def subscribe(self, pairs: Optional[List[str]] = None):
        """Subscribe to market data for given pairs (or all supported pairs)."""
        pairs = pairs or self.SUPPORTED_PAIRS
        for pair in pairs:
            symbol = pair.replace("_", "/").upper()
            req_id = str(self._req_id)
            self._req_id += 1

            # MarketDataRequest (35=V)
            fields = {
                262: req_id,       # MDReqID
                263: "1",          # SubscriptionRequestType: Snapshot + Updates
                264: "1",          # MarketDepth: Top of book
                267: "2",          # NoMDEntryTypes
                269: "0",          # MDEntryType: Bid
                269: "1",          # MDEntryType: Offer (note: repeated tag, simplified)
                146: "1",          # NoRelatedSym
                55: symbol,        # Symbol
            }
            # Build manually to handle repeated tags properly
            sending_time = datetime.now(timezone.utc).strftime("%Y%m%d-%H:%M:%S.%f")[:-3]
            body = ""
            body += fix_field(35, "V")
            body += fix_field(49, self._session.sender)
            body += fix_field(56, self._session.target)
            body += fix_field(34, self._session._seq_num)
            body += fix_field(52, sending_time)
            body += fix_field(262, req_id)
            body += fix_field(263, "1")
            body += fix_field(264, "1")
            body += fix_field(267, "2")
            body += fix_field(269, "0")
            body += fix_field(269, "1")
            body += fix_field(146, "1")
            body += fix_field(55, symbol)

            header = fix_field(8, PepperstoneConfig.FIX_VERSION)
            header += fix_field(9, len(body))
            full_msg = header + body
            checksum = sum(ord(c) for c in full_msg) % 256
            full_msg += fix_field(10, f"{checksum:03d}")

            try:
                self._session._sock.sendall(full_msg.encode("ascii"))
                self._session._seq_num += 1
                logger.debug(f"Subscribed to {symbol}")
            except Exception as e:
                logger.error(f"Subscribe error for {symbol}: {e}")

    def get_price(self, pair: str) -> Optional[Dict]:
        """Return latest cached price for a pair, or None."""
        symbol = pair.replace("_", "/").upper()
        return self._prices.get(symbol)

    def get_all_prices(self) -> Dict[str, Dict]:
        return dict(self._prices)

    def _on_price_message(self, msg: Dict[str, str]):
        """Handle MarketDataSnapshotFullRefresh (35=W) and incremental (35=X)."""
        msg_type = msg.get("35", "")
        if msg_type not in ("W", "X"):
            return

        symbol = msg.get("55", "")
        if not symbol:
            return

        # Parse bid/ask from repeating group entries
        # Tags 269=MDEntryType, 270=MDEntryPx
        # Simplified flat parse (works for top-of-book)
        entries = []
        current_entry = {}
        for tag, val in msg.items():
            if tag == "269":
                if current_entry:
                    entries.append(current_entry)
                current_entry = {"type": val}
            elif tag == "270":
                current_entry["price"] = val
            elif tag == "271":
                current_entry["size"] = val
        if current_entry:
            entries.append(current_entry)

        price_data = self._prices.get(symbol, {"symbol": symbol})
        for entry in entries:
            entry_type = entry.get("type")
            price = entry.get("price")
            if price:
                if entry_type == "0":
                    price_data["bid"] = float(price)
                elif entry_type == "1":
                    price_data["ask"] = float(price)

        if "bid" in price_data and "ask" in price_data:
            price_data["mid"] = round((price_data["bid"] + price_data["ask"]) / 2, 5)
            price_data["spread"] = round(price_data["ask"] - price_data["bid"], 5)

        price_data["timestamp"] = datetime.now(timezone.utc).isoformat()
        price_data["source"] = "pepperstone"
        self._prices[symbol] = price_data
        logger.debug(f"Price update: {symbol} bid={price_data.get('bid')} ask={price_data.get('ask')}")


# ---------------------------------------------------------------------------
# Order Execution
# ---------------------------------------------------------------------------

class PepperOrderManager:
    """
    Sends orders to Pepperstone via FIX trade session.
    Tracks order state via ExecutionReport (35=8) callbacks.
    """

    def __init__(self):
        cfg = PepperstoneConfig
        self._session = FIXSession(
            host=cfg.TRADE_HOST,
            port=cfg.TRADE_PORT,
            sender=cfg.TRADE_SENDER_COMP_ID,
            target=cfg.TRADE_TARGET_COMP_ID,
            account=cfg.ACCOUNT_ID,
            password=cfg.PASSWORD,
            on_message=self._on_trade_message,
        )
        self._orders: Dict[str, Dict] = {}
        self._cl_ord_id = 1
        self._connected = False

    def start(self) -> bool:
        if not self._session.connect():
            return False
        if not self._session.logon():
            return False
        for _ in range(50):
            if self._session._logged_on:
                self._connected = True
                logger.info("Pepper trade session connected")
                return True
            time.sleep(0.1)
        return False

    def stop(self):
        self._session.logout()
        self._connected = False

    def market_order(self, symbol: str, side: str, qty: float,
                     account: Optional[str] = None) -> Optional[str]:
        """
        Place a market order.
        side: 'BUY' or 'SELL'
        qty: lot size (e.g. 0.01 = micro lot)
        Returns client order ID or None on failure.
        """
        if not self._connected:
            logger.error("Trade session not connected")
            return None

        cl_ord_id = f"TAJIR-{int(time.time())}-{self._cl_ord_id}"
        self._cl_ord_id += 1
        fix_side = "1" if side.upper() == "BUY" else "2"
        transact_time = datetime.now(timezone.utc).strftime("%Y%m%d-%H:%M:%S.%f")[:-3]

        fields = {
            11: cl_ord_id,                                # ClOrdID
            55: symbol.replace("_", "/").upper(),         # Symbol
            54: fix_side,                                  # Side
            60: transact_time,                             # TransactTime
            38: str(int(qty * 100000)),                   # OrderQty in units
            40: "1",                                       # OrdType: Market
            1: account or PepperstoneConfig.ACCOUNT_ID,   # Account
        }

        if self._session.send("D", fields):  # 35=D NewOrderSingle
            self._orders[cl_ord_id] = {
                "cl_ord_id": cl_ord_id,
                "symbol": symbol,
                "side": side,
                "qty": qty,
                "status": "PENDING",
                "created_at": transact_time,
            }
            logger.info(f"Market order sent: {side} {qty} {symbol} clOrdId={cl_ord_id}")
            return cl_ord_id
        return None

    def get_order(self, cl_ord_id: str) -> Optional[Dict]:
        return self._orders.get(cl_ord_id)

    def get_all_orders(self) -> Dict[str, Dict]:
        return dict(self._orders)

    def _on_trade_message(self, msg: Dict[str, str]):
        """Handle ExecutionReport (35=8)."""
        if msg.get("35") != "8":
            return

        cl_ord_id = msg.get("11", "")
        ord_status = msg.get("39", "")
        exec_type = msg.get("150", "")

        status_map = {
            "0": "NEW", "1": "PARTIAL", "2": "FILLED",
            "4": "CANCELLED", "8": "REJECTED", "A": "PENDING",
        }

        if cl_ord_id in self._orders:
            self._orders[cl_ord_id]["status"] = status_map.get(ord_status, ord_status)
            if msg.get("31"):  # LastPx — fill price
                self._orders[cl_ord_id]["fill_price"] = float(msg["31"])
            if msg.get("32"):  # LastQty
                self._orders[cl_ord_id]["fill_qty"] = float(msg["32"])
            if ord_status == "8":
                reason = msg.get("103", msg.get("58", "unknown"))
                self._orders[cl_ord_id]["reject_reason"] = reason
                logger.warning(f"Order rejected {cl_ord_id}: {reason}")
            else:
                logger.info(f"Order update {cl_ord_id}: status={status_map.get(ord_status)}")


# ---------------------------------------------------------------------------
# Public Service Interface (used by FastAPI routes)
# ---------------------------------------------------------------------------

class PepperTradingService:
    """
    Singleton service that manages both price feed and trade sessions.
    Import and use this in market_routes.py and order_routes.py.

    Usage:
        from app.services.pepper_trading_service import pepper_service

        # Get price
        price = pepper_service.get_price("EUR_USD")

        # Place order
        order_id = pepper_service.place_order("EUR_USD", "BUY", 0.01)
    """

    def __init__(self):
        self._price_feed = PepperPriceFeed()
        self._order_manager = PepperOrderManager()
        self._started = False
        self._price_started = False
        self._trade_started = False

    def start(self, start_trade: bool = True) -> Dict:
        """
        Start price feed (and optionally trade session).
        Call this during FastAPI startup or on first request.
        """
        result = {"price_feed": False, "trade_session": False, "errors": []}

        missing = PepperstoneConfig.validate()
        if missing:
            result["errors"].append(f"Missing env vars: {missing}")
            return result

        # Start price feed
        try:
            if self._price_feed.start():
                self._price_feed.subscribe()  # Subscribe to all pairs
                self._price_started = True
                result["price_feed"] = True
                logger.info("Pepper price feed started")
            else:
                result["errors"].append("Price feed connection failed")
        except Exception as e:
            result["errors"].append(f"Price feed error: {e}")
            logger.error(f"Price feed start error: {e}")

        # Start trade session (optional — only needed for live orders)
        if start_trade:
            try:
                if self._order_manager.start():
                    self._trade_started = True
                    result["trade_session"] = True
                    logger.info("Pepper trade session started")
                else:
                    result["errors"].append("Trade session connection failed")
            except Exception as e:
                result["errors"].append(f"Trade session error: {e}")
                logger.error(f"Trade session start error: {e}")

        self._started = self._price_started
        return result

    def stop(self):
        """Graceful shutdown — call during FastAPI shutdown."""
        self._price_feed.stop()
        self._order_manager.stop()
        self._started = False
        logger.info("Pepper trading service stopped")

    # ------------------------------------------------------------------
    # Price methods
    # ------------------------------------------------------------------

    def get_price(self, pair: str) -> Optional[Dict]:
        """
        Return latest price for a pair.
        pair format: 'EUR_USD' or 'EUR/USD'
        Returns: {symbol, bid, ask, mid, spread, timestamp, source}
        """
        if not self._price_started:
            return None
        return self._price_feed.get_price(pair)

    def get_prices(self, pairs: Optional[List[str]] = None) -> Dict[str, Dict]:
        """Return all cached prices, optionally filtered by pairs list."""
        if not self._price_started:
            return {}
        all_prices = self._price_feed.get_all_prices()
        if pairs:
            symbols = {p.replace("_", "/").upper() for p in pairs}
            return {k: v for k, v in all_prices.items() if k in symbols}
        return all_prices

    def is_price_feed_live(self) -> bool:
        return self._price_started and self._price_feed._session._logged_on

    # ------------------------------------------------------------------
    # Order methods
    # ------------------------------------------------------------------

    def place_order(self, symbol: str, side: str, qty: float,
                    account: Optional[str] = None) -> Optional[str]:
        """Place a market order. Returns client order ID."""
        if not self._trade_started:
            logger.error("Trade session not started")
            return None
        return self._order_manager.market_order(symbol, side, qty, account)

    def get_order_status(self, cl_ord_id: str) -> Optional[Dict]:
        return self._order_manager.get_order(cl_ord_id)

    def get_all_orders(self) -> Dict[str, Dict]:
        return self._order_manager.get_all_orders()

    # ------------------------------------------------------------------
    # Health / status
    # ------------------------------------------------------------------

    def health(self) -> Dict:
        return {
            "pepper_trading": {
                "price_feed_connected": self._price_feed._session._connected,
                "price_feed_logged_on": self._price_feed._session._logged_on,
                "trade_session_connected": self._order_manager._session._connected,
                "trade_session_logged_on": self._order_manager._session._logged_on,
                "cached_pairs": len(self._price_feed.get_all_prices()),
                "active_orders": len(self._order_manager.get_all_orders()),
            }
        }


# ---------------------------------------------------------------------------
# Singleton instance — import this in routes
# ---------------------------------------------------------------------------

pepper_service = PepperTradingService()


# ---------------------------------------------------------------------------
# FastAPI integration helpers
# ---------------------------------------------------------------------------

async def startup_pepper():
    """
    Call from FastAPI lifespan or @app.on_event("startup"):

        from app.services.pepper_trading_service import startup_pepper
        @app.on_event("startup")
        async def startup():
            await startup_pepper()
    """
    result = await asyncio.to_thread(pepper_service.start)
    if result["errors"]:
        logger.warning(f"Pepper startup warnings: {result['errors']}")
    logger.info(f"Pepper startup result: price_feed={result['price_feed']}, trade={result['trade_session']}")
    return result


async def shutdown_pepper():
    """
    Call from FastAPI shutdown:

        @app.on_event("shutdown")
        async def shutdown():
            await shutdown_pepper()
    """
    await asyncio.to_thread(pepper_service.stop)