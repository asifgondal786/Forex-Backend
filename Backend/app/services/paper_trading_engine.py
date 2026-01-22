"""
Paper Trading Engine
Simulates live trading without real money
Builds user confidence before enabling real trading
"""
from dataclasses import dataclass, field
from datetime import datetime, timedelta
from typing import Dict, List, Optional
from enum import Enum
import random


@dataclass
class PaperTrade:
    """Simulated trade"""
    trade_id: str
    user_id: str
    pair: str
    action: str  # BUY, SELL
    entry_price: float
    entry_time: datetime
    position_size: float  # Simulated units
    stop_loss: float
    take_profit: float
    
    exit_price: Optional[float] = None
    exit_time: Optional[datetime] = None
    status: str = "open"  # "open", "closed", "stopped_out"
    profit_loss: Optional[float] = None
    profit_loss_percent: Optional[float] = None
    is_simulated: bool = True


@dataclass
class PaperTradingAccount:
    """Simulated trading account"""
    account_id: str
    user_id: str
    starting_balance: float
    current_balance: float
    available_margin: float
    created_at: datetime
    
    total_trades: int = 0
    winning_trades: int = 0
    losing_trades: int = 0
    total_profit_loss: float = 0.0
    win_rate: float = 0.0
    max_drawdown: float = 0.0
    max_profit: float = 0.0
    
    open_trades: List[PaperTrade] = field(default_factory=list)
    closed_trades: List[PaperTrade] = field(default_factory=list)


class PaperTradingEngine:
    """
    Paper trading simulation engine
    Helps users test strategies with live data but no real money
    """
    
    def __init__(self):
        self.accounts: Dict[str, PaperTradingAccount] = {}
        self.all_trades: List[PaperTrade] = []
        
        # Simulated live prices (in production, fetch from real API)
        self.live_prices = {
            "EUR/USD": 1.1050,
            "GBP/USD": 1.2750,
            "USD/JPY": 105.50,
            "AUD/USD": 0.7350,
            "USD/CHF": 0.9200,
            "NZD/USD": 0.6850,
            "USD/CAD": 1.2450,
        }

    async def create_paper_trading_account(
        self,
        user_id: str,
        starting_balance: float = 10000.0
    ) -> Dict:
        """Create a paper trading account"""
        
        account_id = f"paper_{user_id}_{datetime.now().timestamp()}"
        
        account = PaperTradingAccount(
            account_id=account_id,
            user_id=user_id,
            starting_balance=starting_balance,
            current_balance=starting_balance,
            available_margin=starting_balance,
            created_at=datetime.now()
        )
        
        self.accounts[user_id] = account
        
        return {
            "success": True,
            "account_id": account_id,
            "message": "Paper trading account created",
            "details": {
                "starting_balance": starting_balance,
                "available_margin": starting_balance,
                "account_type": "SIMULATION - No real money involved"
            }
        }

    async def open_paper_trade(
        self,
        user_id: str,
        pair: str,
        action: str,
        position_size: float,
        entry_price: Optional[float] = None,
        stop_loss: float = 0,
        take_profit: float = 0
    ) -> Dict:
        """Open a simulated trade"""
        
        account = self.accounts.get(user_id)
        if not account:
            return {"error": "Paper trading account not found"}
        
        # Use provided price or current market price
        current_price = entry_price or self.live_prices.get(pair, 1.0)
        
        # Check margin
        notional_value = position_size * current_price
        if notional_value > account.available_margin:
            return {
                "error": "Insufficient margin",
                "required": notional_value,
                "available": account.available_margin
            }
        
        trade_id = f"pt_{user_id}_{datetime.now().timestamp()}"
        
        trade = PaperTrade(
            trade_id=trade_id,
            user_id=user_id,
            pair=pair,
            action=action,
            entry_price=current_price,
            entry_time=datetime.now(),
            position_size=position_size,
            stop_loss=stop_loss or (current_price * 0.99 if action == "BUY" else current_price * 1.01),
            take_profit=take_profit or (current_price * 1.01 if action == "BUY" else current_price * 0.99),
        )
        
        account.open_trades.append(trade)
        account.available_margin -= notional_value
        self.all_trades.append(trade)
        
        return {
            "success": True,
            "trade_id": trade_id,
            "message": f"Paper trade opened: {action} {pair}",
            "details": {
                "pair": pair,
                "action": action,
                "entry_price": current_price,
                "position_size": position_size,
                "stop_loss": trade.stop_loss,
                "take_profit": trade.take_profit,
                "notional_value": notional_value,
                "remaining_margin": account.available_margin
            }
        }

    async def close_paper_trade(
        self,
        user_id: str,
        trade_id: str,
        exit_price: Optional[float] = None
    ) -> Dict:
        """Close a paper trade"""
        
        account = self.accounts.get(user_id)
        if not account:
            return {"error": "Account not found"}
        
        trade = next((t for t in account.open_trades if t.trade_id == trade_id), None)
        if not trade:
            return {"error": "Trade not found"}
        
        # Calculate exit price
        exit_price = exit_price or self.live_prices.get(trade.pair, trade.entry_price)
        
        # Calculate P&L
        if trade.action == "BUY":
            pnl = (exit_price - trade.entry_price) * trade.position_size
        else:  # SELL
            pnl = (trade.entry_price - exit_price) * trade.position_size
        
        pnl_percent = (pnl / (trade.entry_price * trade.position_size)) * 100
        
        # Update trade
        trade.exit_price = exit_price
        trade.exit_time = datetime.now()
        trade.status = "closed"
        trade.profit_loss = pnl
        trade.profit_loss_percent = pnl_percent
        
        # Update account
        account.open_trades.remove(trade)
        account.closed_trades.append(trade)
        account.current_balance += pnl
        account.available_margin += (trade.position_size * trade.entry_price)  # Free up margin
        account.total_trades += 1
        
        if pnl > 0:
            account.winning_trades += 1
            account.max_profit = max(account.max_profit, pnl)
        else:
            account.losing_trades += 1
            drawdown = abs(pnl) / account.starting_balance * 100
            account.max_drawdown = max(account.max_drawdown, drawdown)
        
        account.total_profit_loss += pnl
        account.win_rate = (account.winning_trades / max(account.total_trades, 1)) * 100
        
        return {
            "success": True,
            "trade_id": trade_id,
            "message": f"Paper trade closed with {pnl:+.2f} profit",
            "details": {
                "pair": trade.pair,
                "action": trade.action,
                "entry_price": trade.entry_price,
                "exit_price": exit_price,
                "position_size": trade.position_size,
                "profit_loss": pnl,
                "profit_loss_percent": f"{pnl_percent:+.2f}%",
                "duration": str(trade.exit_time - trade.entry_time).split('.')[0]
            }
        }

    async def get_paper_account_summary(self, user_id: str) -> Dict:
        """Get paper trading account summary"""
        
        account = self.accounts.get(user_id)
        if not account:
            return {"error": "Account not found"}
        
        return {
            "account_id": account.account_id,
            "balance": {
                "starting": account.starting_balance,
                "current": account.current_balance,
                "available_margin": account.available_margin,
                "total_profit_loss": account.total_profit_loss,
                "return_percent": (account.total_profit_loss / account.starting_balance) * 100,
            },
            "statistics": {
                "total_trades": account.total_trades,
                "winning_trades": account.winning_trades,
                "losing_trades": account.losing_trades,
                "win_rate": f"{account.win_rate:.1f}%",
                "max_profit": account.max_profit,
                "max_drawdown": f"{account.max_drawdown:.2f}%",
            },
            "open_trades": len(account.open_trades),
            "closed_trades": len(account.closed_trades),
            "created_at": account.created_at.isoformat(),
            "message": "✅ Paper trading account - No real money involved. Use to test strategies with live market data!"
        }

    async def get_paper_trades(self, user_id: str, status: str = "all") -> List[Dict]:
        """Get paper trades"""
        
        account = self.accounts.get(user_id)
        if not account:
            return []
        
        trades = []
        if status in ["all", "open"]:
            trades.extend(account.open_trades)
        if status in ["all", "closed"]:
            trades.extend(account.closed_trades)
        
        return [
            {
                "trade_id": t.trade_id,
                "pair": t.pair,
                "action": t.action,
                "entry_price": t.entry_price,
                "entry_time": t.entry_time.isoformat(),
                "exit_price": t.exit_price,
                "exit_time": t.exit_time.isoformat() if t.exit_time else None,
                "position_size": t.position_size,
                "status": t.status,
                "profit_loss": t.profit_loss,
                "profit_loss_percent": f"{t.profit_loss_percent:.2f}%" if t.profit_loss_percent else None,
            }
            for t in trades
        ]

    async def update_live_prices(self, price_data: Dict[str, float]) -> Dict:
        """Update simulated live prices"""
        
        for pair, price in price_data.items():
            if pair in self.live_prices:
                self.live_prices[pair] = price
        
        # Check if any stop losses or take profits should be triggered
        triggered = await self._check_trade_triggers()
        
        return {
            "success": True,
            "prices_updated": len(price_data),
            "trades_triggered": triggered
        }

    async def _check_trade_triggers(self) -> int:
        """Check for stop loss / take profit triggers"""
        triggered_count = 0
        
        for trade in self.all_trades:
            if trade.status != "open":
                continue
            
            current_price = self.live_prices.get(trade.pair, trade.entry_price)
            
            # Check stop loss
            if trade.action == "BUY" and current_price <= trade.stop_loss:
                await self.close_paper_trade(trade.user_id, trade.trade_id, trade.stop_loss)
                trade.status = "stopped_out"
                triggered_count += 1
            
            elif trade.action == "SELL" and current_price >= trade.stop_loss:
                await self.close_paper_trade(trade.user_id, trade.trade_id, trade.stop_loss)
                trade.status = "stopped_out"
                triggered_count += 1
            
            # Check take profit
            elif trade.action == "BUY" and current_price >= trade.take_profit:
                await self.close_paper_trade(trade.user_id, trade.trade_id, trade.take_profit)
                triggered_count += 1
            
            elif trade.action == "SELL" and current_price <= trade.take_profit:
                await self.close_paper_trade(trade.user_id, trade.trade_id, trade.take_profit)
                triggered_count += 1
        
        return triggered_count

    async def compare_paper_vs_real(self, user_id: str) -> Dict:
        """
        Compare paper trading results with real trading results
        Shows user how well they would have done
        """
        
        account = self.accounts.get(user_id)
        if not account:
            return {"error": "Account not found"}
        
        return {
            "paper_account": {
                "starting_balance": account.starting_balance,
                "current_balance": account.current_balance,
                "total_return": f"{(account.total_profit_loss / account.starting_balance * 100):+.2f}%",
                "total_trades": account.total_trades,
                "win_rate": f"{account.win_rate:.1f}%",
                "max_drawdown": f"{account.max_drawdown:.2f}%",
            },
            "insights": [
                "✅ Paper trading helps you test strategies risk-free",
                f"📊 You've completed {account.total_trades} simulated trades",
                f"🎯 Your win rate is {account.win_rate:.1f}%",
                "💡 When ready, you can enable real trading with the same strategy",
                "⚠️ Remember: Real trading involves actual financial risk"
            ],
            "recommendations": self._get_paper_trading_recommendations(account)
        }

    def _get_paper_trading_recommendations(self, account: PaperTradingAccount) -> List[str]:
        """Get recommendations based on paper trading performance"""
        recommendations = []
        
        if account.total_trades < 10:
            recommendations.append("Complete at least 10 trades to get meaningful statistics")
        
        if account.win_rate > 60:
            recommendations.append("🟢 Strong performance! You may be ready for small real trades")
        elif account.win_rate > 50:
            recommendations.append("🟡 Decent performance. Keep paper trading to build consistency")
        else:
            recommendations.append("🔴 Win rate below 50%. Work on your strategy before real trading")
        
        if account.max_drawdown > 30:
            recommendations.append("⚠️ High drawdown - consider tighter stop losses")
        
        return recommendations

    async def get_paper_trading_guide(self) -> Dict:
        """Get guide for paper trading"""
        
        return {
            "purpose": "Test your trading strategy with live market data without risking real money",
            "benefits": [
                "✅ Risk-free testing",
                "✅ Real market prices",
                "✅ Build confidence",
                "✅ Develop strategy",
                "✅ Track performance",
            ],
            "steps": [
                "1. Create a paper trading account",
                "2. Set initial capital ($10,000 recommended)",
                "3. Execute trades based on your strategy",
                "4. Track results and analyze performance",
                "5. When confident, transition to small real trades",
            ],
            "best_practices": [
                "Trade as if it were real money",
                "Use your actual risk management rules",
                "Document your reasoning for each trade",
                "Track emotions and psychology",
                "Don't overtrade - quality > quantity",
                "Aim for minimum 10-20 trades before going live",
            ],
            "ready_to_go_live": "When you're consistently profitable with good risk management"
        }
