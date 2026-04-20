"""
Broker Execution Service
Centralizes broker account bindings and broker-side execution handoff.
"""
from __future__ import annotations

from datetime import datetime
from typing import Dict, List, Optional, Tuple
import os
import uuid
import base64

import httpx


class BrokerExecutionService:
    def __init__(self) -> None:
        self._connections_by_user: Dict[str, List[Dict]] = {}
        self._timeout_seconds = float(os.getenv("FOREX_COM_HTTP_TIMEOUT_SECONDS", "12"))
        self._bootstrap_dev_connection("dev_user_001")

    def _bootstrap_dev_connection(self, user_id: str) -> None:
        if user_id in self._connections_by_user and self._connections_by_user[user_id]:
            return
        default_mode = self._default_account_mode()
        self._connections_by_user[user_id] = [
            {
                "id": "demo-gondalgondal0000vlk2",
                "broker": "Forex.com",
                "account_number": "demo-gondalgondal0000vlk2",
                "balance": 10000.0,
                "currency": "USD",
                "status": "connected",
                "last_updated": "2024-01-15T10:30:00Z",
                "mode": default_mode,
            }
        ]

    def _ensure_user_connections(self, user_id: str) -> List[Dict]:
        if user_id not in self._connections_by_user:
            self._connections_by_user[user_id] = []
        if user_id.startswith("dev_") and not self._connections_by_user[user_id]:
            self._bootstrap_dev_connection(user_id)
        return self._connections_by_user[user_id]

    def get_account_connections(self, user_id: str) -> List[Dict]:
        return list(self._ensure_user_connections(user_id))

    def _default_account_mode(self) -> str:
        mode = os.getenv("FOREX_COM_DEFAULT_ACCOUNT_MODE", "demo").strip().lower()
        return "live" if mode == "live" else "demo"

    def infer_account_mode(self, username: str) -> str:
        mode = self._default_account_mode()
        lowered = (username or "").strip().lower()
        if lowered.startswith("live_"):
            return "live"
        if lowered.startswith("demo_"):
            return "demo"
        return mode

    def connect_forex_account(self, user_id: str, username: str, password: str) -> Dict:
        if not username or not password:
            raise ValueError("Username and password are required")

        connections = self._ensure_user_connections(user_id)
        account_id = f"forex_{uuid.uuid4().hex[:16]}"
        account_number = f"FX_{username[-6:]}_{uuid.uuid4().hex[:4]}".upper()
        mode = self.infer_account_mode(username)

        connection = {
            "id": account_id,
            "broker": "Forex.com",
            "account_number": account_number,
            "balance": 10000.0,
            "currency": "USD",
            "status": "connected",
            "last_updated": datetime.now().isoformat(),
            "mode": mode,
        }
        connections.append(connection)
        return connection

    def disconnect_account(self, user_id: str, account_id: str) -> bool:
        connections = self._ensure_user_connections(user_id)
        before = len(connections)
        self._connections_by_user[user_id] = [
            conn for conn in connections if conn.get("id") != account_id
        ]
        return len(self._connections_by_user[user_id]) < before

    def get_account_balance(self, user_id: str, account_id: str) -> Optional[Tuple[float, str]]:
        for conn in self._ensure_user_connections(user_id):
            if conn.get("id") == account_id and conn.get("status") == "connected":
                return float(conn.get("balance", 0.0)), str(conn.get("currency", "USD"))
        return None

    def _select_connected_account(self, user_id: str, account_id: Optional[str]) -> Optional[Dict]:
        connections = self._ensure_user_connections(user_id)
        connected = [c for c in connections if c.get("status") == "connected"]
        if not connected:
            return None

        if account_id:
            for conn in connected:
                if conn.get("id") == account_id:
                    return conn
            return None
        return connected[0]

    def _is_live_execution_enabled(self) -> bool:
        enabled = os.getenv("FOREX_COM_LIVE_EXECUTION", "false").lower() == "true"
        return enabled

    def _forex_order_endpoint(self) -> str:
        explicit = os.getenv("FOREX_COM_ORDER_ENDPOINT", "").strip()
        if explicit:
            return explicit
        base = os.getenv("FOREX_COM_BASE_URL", "").strip().rstrip("/")
        path = os.getenv("FOREX_COM_ORDER_PATH", "/v1/orders").strip()
        if not base:
            return ""
        if not path.startswith("/"):
            path = f"/{path}"
        return f"{base}{path}"

    def _auth_mode(self) -> str:
        mode = os.getenv("FOREX_COM_AUTH_MODE", "bearer").strip().lower()
        if mode in {"bearer", "basic", "header_pair"}:
            return mode
        return "bearer"

    def _validate_live_config(self) -> Tuple[bool, str]:
        endpoint = self._forex_order_endpoint()
        if not endpoint:
            return False, "FOREX_COM_ORDER_ENDPOINT (or BASE_URL + ORDER_PATH) is not configured"

        api_key = os.getenv("FOREX_COM_API_KEY", "").strip()
        api_secret = os.getenv("FOREX_COM_API_SECRET", "").strip()
        if not api_key:
            return False, "FOREX_COM_API_KEY is missing"
        if self._auth_mode() in {"basic", "header_pair"} and not api_secret:
            return False, "FOREX_COM_API_SECRET is required for the selected auth mode"
        return True, ""

    def _build_live_headers(self) -> Dict[str, str]:
        api_key = os.getenv("FOREX_COM_API_KEY", "").strip()
        api_secret = os.getenv("FOREX_COM_API_SECRET", "").strip()
        auth_mode = self._auth_mode()

        headers = {
            "Content-Type": "application/json",
            "Accept": "application/json",
        }

        if auth_mode == "bearer":
            headers["Authorization"] = f"Bearer {api_key}"
        elif auth_mode == "basic":
            token = base64.b64encode(f"{api_key}:{api_secret}".encode("utf-8")).decode("utf-8")
            headers["Authorization"] = f"Basic {token}"
        else:  # header_pair
            headers["X-API-KEY"] = api_key
            headers["X-API-SECRET"] = api_secret

        tenant_id = os.getenv("FOREX_COM_TENANT_ID", "").strip()
        client_id = os.getenv("FOREX_COM_CLIENT_ID", "").strip()
        if tenant_id:
            headers["X-TENANT-ID"] = tenant_id
        if client_id:
            headers["X-CLIENT-ID"] = client_id
        return headers

    def _pair_to_symbol(self, pair: str) -> str:
        symbol_format = os.getenv("FOREX_COM_SYMBOL_FORMAT", "slash").strip().lower()
        if symbol_format == "compact":
            return pair.replace("/", "")
        return pair

    def _side_value(self, action: str) -> str:
        side_format = os.getenv("FOREX_COM_SIDE_FORMAT", "lower").strip().lower()
        action = action.strip().upper()
        if side_format == "upper":
            return action
        return action.lower()

    def _build_live_order_payload(self, trade_params: Dict, account: Dict) -> Dict:
        order_type = os.getenv("FOREX_COM_ORDER_TYPE", "market").strip().lower()
        client_order_id = str(trade_params.get("client_order_id") or f"cli_{uuid.uuid4().hex[:12]}")
        payload: Dict[str, object] = {
            "accountId": account.get("account_number"),
            "symbol": self._pair_to_symbol(str(trade_params.get("pair", ""))),
            "side": self._side_value(str(trade_params.get("action", ""))),
            "type": order_type,
            "quantity": float(trade_params.get("position_size", 0.0) or 0.0),
            "clientOrderId": client_order_id,
        }

        stop_loss = trade_params.get("stop_loss")
        take_profit = trade_params.get("take_profit")
        if stop_loss is not None:
            payload["stopLoss"] = float(stop_loss)
        if take_profit is not None:
            payload["takeProfit"] = float(take_profit)

        # Optional execution hints
        tif = os.getenv("FOREX_COM_TIME_IN_FORCE", "").strip()
        if tif:
            payload["timeInForce"] = tif

        return payload

    def _extract_value(self, data: object, keys: List[str], fallback: str = "") -> str:
        if not isinstance(data, dict):
            return fallback
        for key in keys:
            value = data.get(key)
            if value is not None and str(value).strip():
                return str(value)
        return fallback

    async def _execute_live_order(self, trade_params: Dict, account: Dict) -> Dict:
        config_ok, config_error = self._validate_live_config()
        if not config_ok:
            return {
                "success": False,
                "error": f"Forex.com live execution is enabled but misconfigured: {config_error}",
                "configuration_error": True,
            }

        endpoint = self._forex_order_endpoint()
        headers = self._build_live_headers()
        payload = self._build_live_order_payload(trade_params, account)

        try:
            async with httpx.AsyncClient(timeout=self._timeout_seconds) as client:
                response = await client.post(endpoint, headers=headers, json=payload)
        except httpx.TimeoutException:
            return {
                "success": False,
                "error": "Forex.com order request timed out",
                "broker": "Forex.com",
            }
        except httpx.RequestError as exc:
            return {
                "success": False,
                "error": f"Forex.com request failed: {exc}",
                "broker": "Forex.com",
            }

        try:
            data = response.json() if response.text else {}
        except Exception:
            data = {"raw": response.text[:500] if response.text else ""}

        if response.status_code < 200 or response.status_code >= 300:
            return {
                "success": False,
                "error": "Forex.com order rejected",
                "broker": "Forex.com",
                "broker_http_status": response.status_code,
                "broker_response": data,
            }

        order_id = self._extract_value(
            data,
            [
                "orderId",
                "order_id",
                "id",
                "dealReference",
                "deal_reference",
            ],
            fallback=f"fxc_{uuid.uuid4().hex[:14]}",
        )
        status = self._extract_value(
            data,
            ["status", "orderStatus", "order_status"],
            fallback="accepted",
        )
        executed_price = self._extract_value(
            data,
            ["executedPrice", "filledPrice", "price", "executionPrice"],
            fallback=str(trade_params.get("entry_price") or ""),
        )

        return {
            "success": True,
            "broker": "Forex.com",
            "account_id": account.get("id"),
            "account_number": account.get("account_number"),
            "broker_order_id": order_id,
            "status": status,
            "execution_mode": "live_bridge",
            "executed_at": datetime.now().isoformat(),
            "executed_price": executed_price,
            "message": "Order submitted to Forex.com live endpoint.",
            "broker_http_status": response.status_code,
            "broker_response": data,
        }

    async def execute_trade(self, user_id: str, trade_params: Dict) -> Dict:
        requested_account_id = str(trade_params.get("account_id") or "").strip() or None
        account = self._select_connected_account(user_id, requested_account_id)
        if not account:
            return {
                "success": False,
                "error": "No connected broker account available for live execution",
                "requires_account_connection": True,
            }

        if str(account.get("broker", "")).lower() != "forex.com":
            return {
                "success": False,
                "error": "Only Forex.com broker accounts are supported for autonomous execution",
                "account_id": account.get("id"),
            }

        account_mode = str(account.get("mode", "demo")).lower()
        if self._is_live_execution_enabled() and account_mode == "live":
            return await self._execute_live_order(trade_params=trade_params, account=account)

        broker_order_id = f"fxc_{uuid.uuid4().hex[:14]}"
        return {
            "success": True,
            "broker": "Forex.com",
            "account_id": account.get("id"),
            "account_number": account.get("account_number"),
            "broker_order_id": broker_order_id,
            "status": "filled",
            "execution_mode": "simulated_bridge",
            "executed_at": datetime.now().isoformat(),
            "executed_price": trade_params.get("entry_price"),
            "message": "Order executed via broker bridge simulation (live mode disabled or account is demo).",
        }


broker_execution_service = BrokerExecutionService()
