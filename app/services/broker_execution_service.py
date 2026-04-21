"""
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
