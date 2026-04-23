"""
AI-Powered Forex Trading Engine
Autonomous trading system that works while you sleep
Uses DeepSeek AI for intelligent decision-making
"""
import aiohttp
from datetime import datetime, timedelta
from typing import Dict, List, Optional, Tuple, Any
import numpy as np
from dataclasses import dataclass
import json

from .ai import RiskEngine, StrategyEngine, deepseek_client


@dataclass
class TradingSignal:
    pair: str
    action: str
    confidence: float
    entry_price: float
    stop_loss: float
    take_profit: float
    reason: str
    timestamp: datetime


@dataclass
class MarketCondition:
    pair: str
    current_price: float
    trend: str
    volatility: float
    support_level: float
    resistance_level: float
    rsi: float
    macd: Dict[str, float]


class ForexAIEngine:

    def __init__(self):
        self.session: Optional[aiohttp.ClientSession] = None
        self.active_positions: Dict[str, Dict] = {}
        self.user_preferences: Dict[str, Any] = {}
        self.strategy_engine = StrategyEngine()
        self.risk_engine = RiskEngine()

    async def initialize(self):
        if not self.session:
            self.session = aiohttp.ClientSession()

    async def close(self):
        if self.session:
            await self.session.close()
            self.session = None

    async def fetch_live_rates(self) -> Dict[str, float]:
        try:
            url = "https://api.exchangerate-api.com/v4/latest/USD"
            async with self.session.get(url, timeout=10) as response:
                if response.status == 200:
                    data = await response.json()
                    return {
                        "EUR/USD": 1 / data["rates"]["EUR"],
                        "GBP/USD": 1 / data["rates"]["GBP"],
                        "USD/JPY": data["rates"]["JPY"],
                        "USD/CHF": data["rates"]["CHF"],
                        "AUD/USD": 1 / data["rates"]["AUD"],
                        "USD/CAD": data["rates"]["CAD"],
                        "NZD/USD": 1 / data["rates"]["NZD"],
                        "EUR/GBP": data["rates"]["GBP"] / data["rates"]["EUR"],
                    }
        except Exception as e:
            print(f"Error fetching rates: {e}")
        return {}

    def calculate_rsi(self, prices: List[float], period: int = 14) -> float:
        if len(prices) < period + 1:
            return 50.0
        deltas = np.diff(prices)
        gains = np.where(deltas > 0, deltas, 0)
        losses = np.where(deltas < 0, -deltas, 0)
        avg_gain = np.mean(gains[:period])
        avg_loss = np.mean(losses[:period])
        if avg_loss == 0:
            return 100.0
        return 100 - (100 / (1 + avg_gain / avg_loss))

    def calculate_macd(self, prices: List[float]) -> Dict[str, float]:
        if len(prices) < 26:
            return {"macd": 0, "signal": 0, "histogram": 0}
        prices_array = np.array(prices)
        ema_12 = self._calculate_ema(prices_array, 12)
        ema_26 = self._calculate_ema(prices_array, 26)
        macd_line = ema_12 - ema_26
        signal_line = self._calculate_ema(np.array([macd_line]), 9)
        return {"macd": macd_line, "signal": signal_line, "histogram": macd_line - signal_line}

    def _calculate_ema(self, prices: np.ndarray, period: int) -> float:
        multiplier = 2 / (period + 1)
        ema = prices[0]
        for price in prices[1:]:
            ema = (price * multiplier) + (ema * (1 - multiplier))
        return ema

    def identify_support_resistance(self, prices: List[float]) -> Tuple[float, float]:
        recent = prices[-50:] if len(prices) > 50 else prices
        return min(recent), max(recent)

    async def analyze_market_conditions(self, pair: str, historical_prices: List[float]) -> MarketCondition:
        current_price = historical_prices[-1]
        rsi = self.calculate_rsi(historical_prices)
        macd = self.calculate_macd(historical_prices)
        support, resistance = self.identify_support_resistance(historical_prices)
        sma_20 = np.mean(historical_prices[-20:])
        sma_50 = np.mean(historical_prices[-50:]) if len(historical_prices) >= 50 else sma_20
        if sma_20 > sma_50 and current_price > sma_20:
            trend = "BULLISH"
        elif sma_20 < sma_50 and current_price < sma_20:
            trend = "BEARISH"
        else:
            trend = "SIDEWAYS"
        return MarketCondition(
            pair=pair, current_price=current_price, trend=trend,
            volatility=float(np.std(historical_prices[-20:])),
            support_level=support, resistance_level=resistance, rsi=rsi, macd=macd
        )

    async def generate_trading_signal_with_ai(
        self, pair: str, market_condition: MarketCondition,
        user_strategy: Dict, historical_data: List[Dict]
    ) -> TradingSignal:
        try:
            if not deepseek_client.available:
                return await self.generate_trading_signal(pair, market_condition, user_strategy)

            prompt = f"""You are an expert forex trading signal generator.

MARKET CONDITIONS FOR {pair}:
- Current Price: {market_condition.current_price:.5f}
- Trend: {market_condition.trend}
- RSI: {market_condition.rsi:.1f}
- MACD: {market_condition.macd["macd"]:.3f}
- Volatility: {market_condition.volatility:.5f}
- Support: {market_condition.support_level:.5f}
- Resistance: {market_condition.resistance_level:.5f}

USER STRATEGY:
{json.dumps(user_strategy, indent=2)}

Generate a trading signal. Return only a JSON object with:
action, confidence, entry_price, stop_loss, take_profit, reason"""

            signal_data = deepseek_client.generate_json(model_name="deepseek-chat", prompt=prompt)
            if not signal_data:
                return await self.generate_trading_signal(pair, market_condition, user_strategy)

            return TradingSignal(
                pair=pair,
                action=signal_data.get("action", "HOLD"),
                confidence=signal_data.get("confidence", 0.0),
                entry_price=signal_data.get("entry_price", market_condition.current_price),
                stop_loss=signal_data.get("stop_loss", 0.0),
                take_profit=signal_data.get("take_profit", 0.0),
                reason=signal_data.get("reason", "AI analysis"),
                timestamp=datetime.now()
            )
        except Exception as e:
            print(f"AI signal generation failed: {e}")
            return await self.generate_trading_signal(pair, market_condition, user_strategy)

    # Aliases for backward compatibility
    async def generate_trading_signal_with_gemini(self, pair, market_condition, user_strategy, historical_data):
        return await self.generate_trading_signal_with_ai(pair, market_condition, user_strategy, historical_data)

    async def generate_trading_signal_with_deepseek(self, pair, market_condition, user_strategy, historical_data):
        return await self.generate_trading_signal_with_ai(pair, market_condition, user_strategy, historical_data)

    async def generate_trading_signal(self, pair, market_condition, user_strategy) -> TradingSignal:
        _ = user_strategy
        decision = self.strategy_engine.generate_signal(market_condition)
        return TradingSignal(
            pair=pair, action=decision.action, confidence=decision.confidence,
            entry_price=decision.entry_price, stop_loss=decision.stop_loss,
            take_profit=decision.take_profit, reason=decision.reason, timestamp=datetime.now()
        )

    async def analyze_portfolio_performance(self, portfolio_data: Dict) -> Dict[str, Any]:
        try:
            if not deepseek_client.available:
                return self._get_default_portfolio_analysis(portfolio_data)
            prompt = f"""You are an expert portfolio analyst.
Analyze this forex trading portfolio:
{json.dumps(portfolio_data, indent=2)}
Return only a JSON object with: performance, risk_level, profitability, recommendations, next_steps."""
            analysis = deepseek_client.generate_json(model_name="deepseek-chat", prompt=prompt)
            if analysis:
                analysis["timestamp"] = datetime.now().isoformat()
                return analysis
        except Exception as e:
            print(f"Portfolio analysis failed: {e}")
        return self._get_default_portfolio_analysis(portfolio_data)

    def _get_default_portfolio_analysis(self, portfolio_data: Dict) -> Dict[str, Any]:
        return {
            "timestamp": datetime.now().isoformat(),
            "performance": "stable", "risk_level": "moderate",
            "profitability": {"overall": portfolio_data.get("total_pnl", 0)},
            "recommendations": ["Review trading strategy", "Monitor key pairs"],
            "next_steps": ["Continue monitoring", "Consider adjustments"]
        }

    async def execute_auto_trade(self, signal: TradingSignal, user_limits: Dict) -> Dict:
        allowed, reason = self.risk_engine.can_execute_signal(signal, min_confidence=0.6)
        if not allowed:
            return {"executed": False, "reason": reason}
        trade = self.risk_engine.build_trade(signal, user_limits)
        self.active_positions[signal.pair] = trade
        return {"executed": True, "trade": trade, "signal": signal}

    async def monitor_positions(self, current_rates: Dict[str, float]):
        closed_trades = []
        for pair, position in list(self.active_positions.items()):
            if pair not in current_rates:
                continue
            closed_trade = self.risk_engine.evaluate_position(position, float(current_rates[pair]))
            if closed_trade:
                closed_trades.append(closed_trade)
                del self.active_positions[pair]
        return closed_trades

    async def forecast_price_movement(self, pair, historical_prices, horizon_hours=24) -> Dict:
        if len(historical_prices) < 10:
            return {"error": "Insufficient data"}
        x = np.arange(len(historical_prices))
        y = np.array(historical_prices)
        coeffs = np.polyfit(x, y, 1)
        forecasted_price = np.polyval(coeffs, len(historical_prices) - 1 + horizon_hours)
        y_pred = np.polyval(coeffs, x)
        ss_res = np.sum((y - y_pred) ** 2)
        ss_tot = np.sum((y - np.mean(y)) ** 2)
        return {
            "pair": pair, "current_price": historical_prices[-1],
            "forecasted_price": float(forecasted_price),
            "expected_change": float(forecasted_price - historical_prices[-1]),
            "confidence": float(1 - ss_res / ss_tot),
            "trend": "UP" if coeffs[0] > 0 else "DOWN",
            "horizon_hours": horizon_hours
        }


ai_engine = ForexAIEngine()
