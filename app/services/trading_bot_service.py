import asyncio
from datetime import datetime
from .forex_data_service import ForexDataService
from .ai_analysis_service import AIAnalysisService
from .notification_service import NotificationService, NotificationType

class TradingBotService:
    """
    Manages automated trading logic, including execution, monitoring,
    and risk management.
    """
    def __init__(self, forex_service: ForexDataService, ai_service: AIAnalysisService, notification_service: NotificationService):
        self._forex_service = forex_service
        self._ai_service = ai_service
        self._notification_service = notification_service
        self._active_trades = {}  # Stores and tracks active trades

    async def execute_trade(self, user_id: str, trade_params: dict):
        """
        Executes a trade based on user parameters and AI validation.
        """
        currency_pair = trade_params.get("currency_pair")
        action = trade_params.get("action")  # "buy" or "sell"
        stop_loss = trade_params.get("stop_loss")
        take_profit = trade_params.get("take_profit")
        
        if not all([currency_pair, action, stop_loss, take_profit]):
            raise ValueError("Missing required trade parameters.")

        # --- AI Validation Step ---
        ai_recommendation = await self._ai_service.get_trade_recommendation(currency_pair)
        
        if ai_recommendation["recommendation"].lower() != action.lower():
            warning_message = f"AI recommends '{ai_recommendation['recommendation']}' but you chose '{action}'. Proceed with caution."
            await self._notification_service.send_notification(
                user_id,
                warning_message,
                NotificationType.WARNING
            )
            # Depending on strictness, you might stop the trade here:
            # return {"success": False, "message": "Trade execution halted due to AI recommendation conflict."}

        # --- Fetch current price before executing ---
        live_price_data = await self._forex_service.get_realtime_price(currency_pair)
        if not live_price_data:
            return {"success": False, "message": "Could not fetch live price data to execute trade."}

        entry_price = live_price_data['price']
        trade_id = f"trade_{user_id}_{datetime.now().timestamp()}"
        
        # --- Placeholder for actual trade execution ---
        # In a real scenario, this would interact with a brokerage API (e.g., OANDA, MetaTrader).
        print(f"Executing {action} trade for {currency_pair} at {entry_price}")
        
        trade_details = {
            "trade_id": trade_id,
            "user_id": user_id,
            "currency_pair": currency_pair,
            "action": action,
            "entry_price": entry_price,
            "stop_loss": stop_loss,
            "take_profit": take_profit,
            "status": "active",
            "timestamp": datetime.now()
        }
        
        self._active_trades[trade_id] = trade_details

        # Start monitoring this trade in the background
        asyncio.create_task(self._monitor_trade(trade_id))

        await self._notification_service.send_notification(
            user_id,
            f"Trade executed: {action} {currency_pair} at {entry_price}",
            NotificationType.SUCCESS
        )

        return {"success": True, "trade": trade_details}

    async def _monitor_trade(self, trade_id: str):
        """
        Monitors an active trade for stop-loss or take-profit triggers.
        Runs as a background task.
        """
        trade = self._active_trades.get(trade_id)
        if not trade:
            return

        user_id = trade["user_id"]
        currency_pair = trade["currency_pair"]
        action = trade["action"]
        stop_loss = trade["stop_loss"]
        take_profit = trade["take_profit"]

        print(f"Monitoring trade {trade_id} for {currency_pair}...")

        while trade["status"] == "active":
            await asyncio.sleep(15) # Check every 15 seconds. In production, use WebSockets for live ticks.

            live_price_data = await self._forex_service.get_realtime_price(currency_pair)
            if not live_price_data:
                continue

            current_price = live_price_data['price']
            
            # --- Check for stop-loss or take-profit ---
            closed = False
            close_reason = ""
            
            if action == "buy":
                if current_price <= stop_loss:
                    closed = True
                    close_reason = f"Stop-loss triggered at {current_price}"
                elif current_price >= take_profit:
                    closed = True
                    close_reason = f"Take-profit triggered at {current_price}"
            
            elif action == "sell":
                if current_price >= stop_loss:
                    closed = True
                    close_reason = f"Stop-loss triggered at {current_price}"
                elif current_price <= take_profit:
                    closed = True
                    close_reason = f"Take-profit triggered at {current_price}"

            if closed:
                await self.close_trade(trade_id, close_reason, current_price)
                break
    
    async def close_trade(self, trade_id: str, reason: str, close_price: float):
        """
        Closes an active trade.
        """
        trade = self._active_trades.get(trade_id)
        if not trade or trade["status"] != "active":
            return

        trade["status"] = "closed"
        trade["close_price"] = close_price
        trade["close_reason"] = reason
        trade["close_timestamp"] = datetime.now()

        # --- Calculate profit/loss ---
        pnl = 0
        if trade["action"] == "buy":
            pnl = close_price - trade["entry_price"]
        else: # sell
            pnl = trade["entry_price"] - close_price
            
        trade["pnl"] = pnl
        
        print(f"Closing trade {trade_id}: {reason}")

        await self._notification_service.send_notification(
            trade["user_id"],
            f"Trade closed for {trade['currency_pair']}. Reason: {reason}. P/L: {pnl:.5f}",
            NotificationType.INFO if pnl >= 0 else NotificationType.ERROR
        )
        
        # Here you might save the closed trade to a database
        
        # Remove from active trades after a delay to ensure no more monitoring
        await asyncio.sleep(5)
        if trade_id in self._active_trades:
            del self._active_trades[trade_id]

async def main():
    """ Test function for TradingBotService. """
    # Mock services
    class MockForex(ForexDataService):
        async def get_realtime_price(self, currency_pair: str):
            return self._generate_mock_price(currency_pair)
            
    class MockAI(AIAnalysisService):
        async def get_trade_recommendation(self, currency_pair: str):
            return {"recommendation": "buy", "confidence": 0.75}

    class MockNotify(NotificationService):
        async def send_notification(self, user_id: str, message: str, notification_type: NotificationType):
            print(f"[{notification_type.name}] To {user_id}: {message}")
            
    # --- Initialize Services ---
    forex = MockForex()
    ai = MockAI()
    notify = MockNotify()
    bot = TradingBotService(forex, ai, notify)
    
    # --- Test Trade Execution ---
    print("--- Executing a test trade ---")
    trade_params = {
        "currency_pair": "EUR/USD",
        "action": "buy",
        "stop_loss": 1.0800,
        "take_profit": 1.0950,
    }
    result = await bot.execute_trade("test_user_123", trade_params)
    print(f"Trade execution result: {result}")
    
    # Let it run for a bit to monitor
    print("\n--- Monitoring active trade (will run for a short period) ---")
    await asyncio.sleep(10)
    
    # Manually close for testing
    trade_id = result["trade"]["trade_id"]
    print(f"\n--- Manually closing trade {trade_id} ---")
    await bot.close_trade(trade_id, "Manual close for test.", 1.0900)

if __name__ == "__main__":
    # This requires ai_analysis_service to exist or be mocked.
    # We will assume it exists for this test.
    asyncio.run(main())
