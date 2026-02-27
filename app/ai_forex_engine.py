"""
AI-Powered Forex Trading Engine
Autonomous trading system that works while you sleep
Integrates with Google Generative AI (Gemini) for intelligent decision-making
"""
import asyncio
import aiohttp
from datetime import datetime, timedelta
from typing import Dict, List, Optional, Tuple, Any
import numpy as np
from dataclasses import dataclass
import json

from .ai import RiskEngine, StrategyEngine, gemini_client


@dataclass
class TradingSignal:
    """Trading signal with AI analysis"""
    pair: str
    action: str  # BUY, SELL, HOLD
    confidence: float
    entry_price: float
    stop_loss: float
    take_profit: float
    reason: str
    timestamp: datetime


@dataclass
class MarketCondition:
    """Current market conditions"""
    pair: str
    current_price: float
    trend: str  # BULLISH, BEARISH, SIDEWAYS
    volatility: float
    support_level: float
    resistance_level: float
    rsi: float
    macd: Dict[str, float]


class ForexAIEngine:
    """
    Comprehensive AI Engine for Forex Trading
    Features:
    1. Real-time market analysis
    2. Automated trading based on user limits
    3. Risk management
    4. Historical pattern recognition
    5. Predictive forecasting
    """
    
    def __init__(self):
        self.session: Optional[aiohttp.ClientSession] = None
        self.active_positions: Dict[str, Dict] = {}
        self.user_preferences: Dict[str, Any] = {}
        self.strategy_engine = StrategyEngine()
        self.risk_engine = RiskEngine()
        
    async def initialize(self):
        """Initialize the AI engine"""
        if not self.session:
            self.session = aiohttp.ClientSession()
    
    async def close(self):
        """Close sessions"""
        if self.session:
            await self.session.close()
            self.session = None
    
    # ========================================================================
    # REAL-TIME DATA FETCHING
    # ========================================================================
    
    async def fetch_live_rates(self) -> Dict[str, float]:
        """Fetch real-time forex rates from multiple sources"""
        try:
            # Primary source: exchangerate-api.com
            url = "https://api.exchangerate-api.com/v4/latest/USD"
            
            async with self.session.get(url, timeout=10) as response:
                if response.status == 200:
                    data = await response.json()
                    
                    # Calculate major pairs
                    rates = {
                        "EUR/USD": 1 / data["rates"]["EUR"],
                        "GBP/USD": 1 / data["rates"]["GBP"],
                        "USD/JPY": data["rates"]["JPY"],
                        "USD/CHF": data["rates"]["CHF"],
                        "AUD/USD": 1 / data["rates"]["AUD"],
                        "USD/CAD": data["rates"]["CAD"],
                        "NZD/USD": 1 / data["rates"]["NZD"],
                        "EUR/GBP": data["rates"]["GBP"] / data["rates"]["EUR"],
                    }
                    
                    return rates
        except Exception as e:
            print(f"Error fetching rates: {e}")
            return {}
    
    async def fetch_economic_calendar(self) -> List[Dict]:
        """Fetch economic events from Forex Factory"""
        # Simulated economic calendar data
        # In production, scrape from forexfactory.com or use paid API
        events = [
            {
                "time": datetime.now() + timedelta(hours=2),
                "currency": "USD",
                "event": "Non-Farm Payrolls",
                "impact": "HIGH",
                "forecast": "180K",
                "previous": "199K"
            },
            {
                "time": datetime.now() + timedelta(hours=6),
                "currency": "EUR",
                "event": "ECB Interest Rate Decision",
                "impact": "HIGH",
                "forecast": "4.50%",
                "previous": "4.50%"
            },
            {
                "time": datetime.now() + timedelta(days=1),
                "currency": "GBP",
                "event": "GDP Growth Rate",
                "impact": "MEDIUM",
                "forecast": "0.2%",
                "previous": "0.1%"
            }
        ]
        return events
    
    # ========================================================================
    # TECHNICAL ANALYSIS
    # ========================================================================
    
    def calculate_rsi(self, prices: List[float], period: int = 14) -> float:
        """Calculate Relative Strength Index"""
        if len(prices) < period + 1:
            return 50.0
        
        deltas = np.diff(prices)
        gains = np.where(deltas > 0, deltas, 0)
        losses = np.where(deltas < 0, -deltas, 0)
        
        avg_gain = np.mean(gains[:period])
        avg_loss = np.mean(losses[:period])
        
        if avg_loss == 0:
            return 100.0
        
        rs = avg_gain / avg_loss
        rsi = 100 - (100 / (1 + rs))
        
        return rsi
    
    def calculate_macd(self, prices: List[float]) -> Dict[str, float]:
        """Calculate MACD (Moving Average Convergence Divergence)"""
        if len(prices) < 26:
            return {"macd": 0, "signal": 0, "histogram": 0}
        
        prices_array = np.array(prices)
        
        # Calculate EMAs
        ema_12 = self._calculate_ema(prices_array, 12)
        ema_26 = self._calculate_ema(prices_array, 26)
        
        macd_line = ema_12 - ema_26
        signal_line = self._calculate_ema(np.array([macd_line]), 9)
        histogram = macd_line - signal_line
        
        return {
            "macd": macd_line,
            "signal": signal_line,
            "histogram": histogram
        }
    
    def _calculate_ema(self, prices: np.ndarray, period: int) -> float:
        """Calculate Exponential Moving Average"""
        multiplier = 2 / (period + 1)
        ema = prices[0]
        
        for price in prices[1:]:
            ema = (price * multiplier) + (ema * (1 - multiplier))
        
        return ema
    
    def identify_support_resistance(self, prices: List[float]) -> Tuple[float, float]:
        """Identify support and resistance levels"""
        recent_prices = prices[-50:] if len(prices) > 50 else prices
        
        support = min(recent_prices)
        resistance = max(recent_prices)
        
        return support, resistance
    
    # ========================================================================
    # AI MARKET ANALYSIS
    # ========================================================================
    
    async def analyze_market_conditions(
        self,
        pair: str,
        historical_prices: List[float]
    ) -> MarketCondition:
        """Comprehensive market analysis using AI"""
        
        current_price = historical_prices[-1]
        
        # Technical indicators
        rsi = self.calculate_rsi(historical_prices)
        macd = self.calculate_macd(historical_prices)
        support, resistance = self.identify_support_resistance(historical_prices)
        
        # Trend identification
        sma_20 = np.mean(historical_prices[-20:])
        sma_50 = np.mean(historical_prices[-50:]) if len(historical_prices) >= 50 else sma_20
        
        if sma_20 > sma_50 and current_price > sma_20:
            trend = "BULLISH"
        elif sma_20 < sma_50 and current_price < sma_20:
            trend = "BEARISH"
        else:
            trend = "SIDEWAYS"
        
        # Volatility (Standard Deviation)
        volatility = float(np.std(historical_prices[-20:]))
        
        return MarketCondition(
            pair=pair,
            current_price=current_price,
            trend=trend,
            volatility=volatility,
            support_level=support,
            resistance_level=resistance,
            rsi=rsi,
            macd=macd
        )
    
    # ========================================================================
    # AI TRADING SIGNALS
    # ========================================================================
    
    async def generate_trading_signal_with_gemini(
        self,
        pair: str,
        market_condition: MarketCondition,
        user_strategy: Dict,
        historical_data: List[Dict]
    ) -> TradingSignal:
        """
        Generate AI-powered trading signal using Google Generative AI (Gemini)
        """
        try:
            if not gemini_client.available:
                return await self.generate_trading_signal(pair, market_condition, user_strategy)
            
            # Format market conditions for analysis
            condition_text = f"""
            MARKET CONDITIONS FOR {pair}:
            - Current Price: {market_condition.current_price:.5f}
            - Trend: {market_condition.trend}
            - RSI: {market_condition.rsi:.1f}
            - MACD: {market_condition.macd['macd']:.3f}
            - Histogram: {market_condition.macd['histogram']:.3f}
            - Volatility: {market_condition.volatility:.5f}
            - Support: {market_condition.support_level:.5f}
            - Resistance: {market_condition.resistance_level:.5f}
            """
            
            # Format historical data
            data_text = "\n".join([
                f"- {data['timestamp']}: {data['close']:.5f}"
                for data in historical_data[-30:]  # Last 30 candles
            ])
            
            prompt = f"""
            You are an expert forex trading signal generator.
            
            Analyze the following for {pair}:
            
            {condition_text}
            
            LAST 30 PRICE CANDLES:
            {data_text}
            
            USER STRATEGY:
            {json.dumps(user_strategy, indent=2)}
            
            Generate a trading signal with:
            1. Action: BUY, SELL, or HOLD
            2. Confidence level (0-100%)
            3. Entry price suggestion
            4. Stop loss level
            5. Take profit level
            6. Detailed reason for the signal
            
            Format your response as JSON.
            """

            signal_data = gemini_client.generate_json(
                model_name="gemini-2.0-flash",
                prompt=prompt,
            )
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
            print(f"Gemini signal generation failed: {e}")
            return await self.generate_trading_signal(pair, market_condition, user_strategy)

    async def generate_trading_signal(
        self,
        pair: str,
        market_condition: MarketCondition,
        user_strategy: Dict
    ) -> TradingSignal:
        """Generate AI-powered trading signal (fallback method)"""
        _ = user_strategy  # Reserved for future strategy profiles.
        decision = self.strategy_engine.generate_signal(market_condition)
        return TradingSignal(
            pair=pair,
            action=decision.action,
            confidence=decision.confidence,
            entry_price=decision.entry_price,
            stop_loss=decision.stop_loss,
            take_profit=decision.take_profit,
            reason=decision.reason,
            timestamp=datetime.now()
        )

    async def analyze_portfolio_performance(self, portfolio_data: Dict) -> Dict[str, Any]:
        """
        Use Google Generative AI (Gemini) to analyze portfolio performance
        """
        try:
            if not gemini_client.available:
                return self._get_default_portfolio_analysis(portfolio_data)
            
            prompt = f"""
            You are an expert portfolio analyst.
            
            Analyze this forex trading portfolio:
            
            {json.dumps(portfolio_data, indent=2)}
            
            Please provide:
            1. Overall performance assessment
            2. Risk analysis
            3. Profitability by currency pair
            4. Trading strategy effectiveness
            5. Improvement recommendations
            6. Next steps
            
            Format your response as JSON.
            """

            analysis = gemini_client.generate_json(
                model_name="gemini-1.5-pro",
                prompt=prompt,
            )
            if not analysis:
                analysis = self._get_default_portfolio_analysis(portfolio_data)
                ai_text = gemini_client.generate_text(
                    model_name="gemini-1.5-pro",
                    prompt=prompt,
                )
                if ai_text:
                    analysis["ai_analysis"] = ai_text
            else:
                analysis["timestamp"] = datetime.now().isoformat()
            return analysis
            
        except Exception as e:
            print(f"Portfolio analysis failed: {e}")
            return self._get_default_portfolio_analysis(portfolio_data)

    def _get_default_portfolio_analysis(self, portfolio_data: Dict) -> Dict[str, Any]:
        """Fallback portfolio analysis when AI is unavailable"""
        return {
            "timestamp": datetime.now().isoformat(),
            "performance": "stable",
            "risk_level": "moderate",
            "profitability": {
                "overall": portfolio_data.get("total_pnl", 0)
            },
            "recommendations": ["Review trading strategy", "Monitor key pairs"],
            "next_steps": ["Continue monitoring", "Consider adjustments"]
        }
    
    # ========================================================================
    # AUTOMATED TRADING
    # ========================================================================
    
    async def execute_auto_trade(
        self,
        signal: TradingSignal,
        user_limits: Dict
    ) -> Dict:
        """
        Execute automated trade based on signal and user limits
        
        user_limits = {
            "max_loss_per_trade": 100,  # USD
            "max_daily_loss": 500,
            "take_profit_at": 100,  # Sell when profit reaches $100
            "stop_loss_at": 50,  # Stop if loss reaches $50
            "max_position_size": 1000  # USD
        }
        """
        
        allowed, reason = self.risk_engine.can_execute_signal(signal, min_confidence=0.6)
        if not allowed:
            return {
                "executed": False,
                "reason": reason
            }
        trade = self.risk_engine.build_trade(signal, user_limits)
        
        # Store active position
        self.active_positions[signal.pair] = trade
        
        return {
            "executed": True,
            "trade": trade,
            "signal": signal
        }
    
    async def monitor_positions(self, current_rates: Dict[str, float]):
        """Monitor and manage active positions"""
        closed_trades = []
        
        for pair, position in list(self.active_positions.items()):
            if pair not in current_rates:
                continue

            current_price = float(current_rates[pair])
            closed_trade = self.risk_engine.evaluate_position(position, current_price)
            if closed_trade:
                closed_trades.append(closed_trade)
                del self.active_positions[pair]
        
        return closed_trades
    
    # ========================================================================
    # FORECASTING & PREDICTIONS
    # ========================================================================
    
    async def forecast_price_movement(
        self,
        pair: str,
        historical_prices: List[float],
        horizon_hours: int = 24
    ) -> Dict:
        """
        AI-powered price forecasting
        Predicts future price movements based on historical data
        """
        
        # Simple linear regression forecast
        # In production, use LSTM, ARIMA, or transformer models
        
        if len(historical_prices) < 10:
            return {"error": "Insufficient data"}
        
        # Calculate trend
        x = np.arange(len(historical_prices))
        y = np.array(historical_prices)
        
        # Linear regression
        coeffs = np.polyfit(x, y, 1)
        slope = coeffs[0]
        
        # Forecast
        last_idx = len(historical_prices) - 1
        forecast_idx = last_idx + horizon_hours
        forecasted_price = np.polyval(coeffs, forecast_idx)
        
        # Confidence based on R² score
        y_pred = np.polyval(coeffs, x)
        ss_res = np.sum((y - y_pred) ** 2)
        ss_tot = np.sum((y - np.mean(y)) ** 2)
        r_squared = 1 - (ss_res / ss_tot)
        
        return {
            "pair": pair,
            "current_price": historical_prices[-1],
            "forecasted_price": float(forecasted_price),
            "expected_change": float(forecasted_price - historical_prices[-1]),
            "expected_change_percent": float((forecasted_price - historical_prices[-1]) / historical_prices[-1] * 100),
            "confidence": float(r_squared),
            "trend": "UP" if slope > 0 else "DOWN",
            "horizon_hours": horizon_hours
        }


# Global AI engine instance
ai_engine = ForexAIEngine()
