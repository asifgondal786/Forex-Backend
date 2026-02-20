# app/services/ai_analysis_service.py
import pandas as pd
import numpy as np
from datetime import datetime, timedelta
from typing import Dict, List, Any
import pandas_ta as ta
from sklearn.preprocessing import MinMaxScaler
from tensorflow import keras
import requests
import os
from dotenv import load_dotenv

try:
    import google.generativeai as genai
except ImportError:
    genai = None

# Load environment variables
load_dotenv()

# Configure Gemini API
GEMINI_API_KEY = os.getenv("GEMINI_API_KEY")
GEMINI_AVAILABLE = bool(GEMINI_API_KEY) and genai is not None
if GEMINI_AVAILABLE:
    genai.configure(api_key=GEMINI_API_KEY)

class AIAnalysisService:
    """
    Advanced AI-powered market analysis using:
    - Technical indicators (pandas-ta)
    - Machine Learning models (LSTM)
    - Pattern recognition
    - Sentiment analysis
    """
    
    def __init__(self):
        self.scaler = MinMaxScaler()
        self.lstm_model = None
        self.load_models()
        
    def load_models(self):
        """Load pre-trained ML models"""
        try:
            # Load LSTM model for price prediction
            if os.path.exists('models/lstm_forex.h5'):
                self.lstm_model = keras.models.load_model('models/lstm_forex.h5')
        except Exception as e:
            print(f"Model loading error: {e}")
    
    async def analyze_news_impact(self, news: List[Dict], currency_pairs: List[str]) -> Dict[str, Any]:
        """
        Use Google Generative AI (Gemini) to analyze news impact on currency pairs
        """
        try:
            if not GEMINI_AVAILABLE:
                return self._get_default_news_analysis(news, currency_pairs)
                
            model = genai.GenerativeModel("gemini-2.0-flash")
            
            # Format news for analysis
            news_text = "\n".join([
                f"- {news_item['time']}: {news_item['currency']} - {news_item['event']} (Impact: {news_item['impact']})"
                for news_item in news
            ])
            
            prompt = f"""
            You are an expert forex news analyst specializing in event impact analysis.
            
            Analyze the impact of economic news on currency pairs:
            
            NEWS ITEMS:
            {news_text}
            
            CURRENCY PAIRS TO ANALYZE:
            {', '.join(currency_pairs)}
            
            Please provide:
            1. Overall market sentiment shift caused by these news items
            2. Impact level for each currency pair
            3. Expected volatility changes
            4. Trading opportunities created by this news
            5. Risk assessment
            6. Timeframe for this analysis
            
            Format your response as JSON.
            """
            
            response = model.generate_content(prompt)
            
            import json
            try:
                analysis = json.loads(response.text)
                analysis["timestamp"] = datetime.now().isoformat()
            except:
                analysis = self._get_default_news_analysis(news, currency_pairs)
                analysis["ai_analysis"] = response.text
                
            return analysis
            
        except Exception as e:
            print(f"News analysis failed: {e}")
            return self._get_default_news_analysis(news, currency_pairs)

    def _get_default_news_analysis(self, news: List[Dict], currency_pairs: List[str]) -> Dict[str, Any]:
        """Fallback news analysis when AI is unavailable"""
        impacts = {}
        for pair in currency_pairs:
            # Determine impact based on currency matches
            news_currencies = [n['currency'] for n in news]
            base_curr, quote_curr = pair.split('/')
            
            if base_curr in news_currencies or quote_curr in news_currencies:
                impacts[pair] = "medium"
            else:
                impacts[pair] = "low"
                
        return {
            "timestamp": datetime.now().isoformat(),
            "sentiment": "neutral",
            "impact_levels": impacts,
            "volatility": "medium",
            "risk": "moderate",
            "trading_opportunities": [],
            "timeframe": "1H"
        }

    async def analyze_news_sentiment(self, news_text: str) -> Dict[str, Any]:
        """
        Use Google Generative AI (Gemini) to analyze sentiment from raw news text
        """
        try:
            if not GEMINI_AVAILABLE:
                return self._get_default_sentiment_analysis()
                
            model = genai.GenerativeModel("gemini-1.5-pro")
            
            prompt = f"""
            You are an expert financial news sentiment analyzer.
            
            Analyze the following news for forex market sentiment:
            
            {news_text}
            
            Please provide:
            1. Overall sentiment (bullish, bearish, neutral)
            2. Sentiment strength (weak, moderate, strong)
            3. Key currency impacts
            4. Volatility expectation
            5. Risk assessment
            6. Trading recommendation
            
            Format your response as JSON.
            """
            
            response = model.generate_content(prompt)
            
            import json
            try:
                sentiment = json.loads(response.text)
                sentiment["timestamp"] = datetime.now().isoformat()
            except:
                sentiment = self._get_default_sentiment_analysis()
                sentiment["ai_analysis"] = response.text
                
            return sentiment
            
        except Exception as e:
            print(f"News sentiment analysis failed: {e}")
            return self._get_default_sentiment_analysis()

    def _get_default_sentiment_analysis(self) -> Dict[str, Any]:
        """Fallback sentiment analysis when AI is unavailable"""
        return {
            "timestamp": datetime.now().isoformat(),
            "sentiment": "neutral",
            "strength": "moderate",
            "currency_impacts": [],
            "volatility": "medium",
            "risk": "moderate",
            "recommendation": "hold"
        }

    def is_healthy(self) -> bool:
        """Check if service is operational"""
        return True
    
    async def analyze_market(
        self, 
        market_data: pd.DataFrame,
        depth: str = "detailed"
    ) -> Dict[str, Any]:
        """
        Comprehensive market analysis
        
        Args:
            market_data: DataFrame with OHLCV data
            depth: quick, detailed, or deep
            
        Returns:
            Complete analysis report
        """
        
        df = market_data.copy()
        
        # Calculate technical indicators
        indicators = self._calculate_indicators(df)
        
        # Detect patterns
        patterns = self._detect_patterns(df)
        
        # Determine trend
        trend_analysis = self._analyze_trend(df, indicators)
        
        # Support/Resistance
        support_resistance = self._find_support_resistance(df)
        
        # Market sentiment
        sentiment = self._analyze_sentiment(df, indicators)
        
        # Generate recommendation
        recommendation = self._generate_recommendation(
            trend_analysis,
            indicators,
            patterns,
            sentiment
        )
        
        return {
            "trend": trend_analysis["direction"],
            "strength": trend_analysis["strength"],
            "support": support_resistance["support"],
            "resistance": support_resistance["resistance"],
            "indicators": indicators,
            "patterns": patterns,
            "sentiment": sentiment,
            "recommendation": recommendation["action"],
            "confidence": recommendation["confidence"],
            "risk_level": recommendation["risk_level"],
            "entry_suggestions": recommendation["entry_points"],
            "stop_loss_suggestions": recommendation["stop_loss"],
            "take_profit_suggestions": recommendation["take_profit"]
        }
    
    def _calculate_indicators(self, df: pd.DataFrame) -> Dict[str, Any]:
        """Calculate comprehensive technical indicators"""
        
        # RSI
        df['rsi'] = ta.rsi(df['close'], length=14)
        
        # MACD
        macd = ta.macd(df['close'])
        df['macd'] = macd['MACD_12_26_9']
        df['macd_signal'] = macd['MACDs_12_26_9']
        df['macd_hist'] = macd['MACDh_12_26_9']
        
        # Bollinger Bands
        bbands = ta.bbands(df['close'], length=20, std=2)
        df['bb_upper'] = bbands['BBU_20_2.0']
        df['bb_middle'] = bbands['BBM_20_2.0']
        df['bb_lower'] = bbands['BBL_20_2.0']
        
        # Moving Averages
        df['sma_20'] = ta.sma(df['close'], length=20)
        df['sma_50'] = ta.sma(df['close'], length=50)
        df['ema_12'] = ta.ema(df['close'], length=12)
        df['ema_26'] = ta.ema(df['close'], length=26)
        
        # ATR (Average True Range)
        df['atr'] = ta.atr(df['high'], df['low'], df['close'], length=14)
        
        # Stochastic
        stoch = ta.stoch(df['high'], df['low'], df['close'])
        df['stoch_k'] = stoch['STOCHk_14_3_3']
        df['stoch_d'] = stoch['STOCHd_14_3_3']
        
        # ADX (Average Directional Index)
        adx = ta.adx(df['high'], df['low'], df['close'], length=14)
        df['adx'] = adx['ADX_14']
        
        # Get latest values
        latest = df.iloc[-1]
        
        return {
            "rsi": {
                "value": float(latest['rsi']),
                "signal": self._interpret_rsi(latest['rsi'])
            },
            "macd": {
                "value": float(latest['macd']),
                "signal": float(latest['macd_signal']),
                "histogram": float(latest['macd_hist']),
                "interpretation": self._interpret_macd(latest)
            },
            "bollinger_bands": {
                "upper": float(latest['bb_upper']),
                "middle": float(latest['bb_middle']),
                "lower": float(latest['bb_lower']),
                "position": self._bb_position(latest)
            },
            "moving_averages": {
                "sma_20": float(latest['sma_20']),
                "sma_50": float(latest['sma_50']),
                "ema_12": float(latest['ema_12']),
                "ema_26": float(latest['ema_26']),
                "trend": self._ma_trend(latest)
            },
            "atr": {
                "value": float(latest['atr']),
                "volatility": self._interpret_atr(latest['atr'], latest['close'])
            },
            "stochastic": {
                "k": float(latest['stoch_k']),
                "d": float(latest['stoch_d']),
                "signal": self._interpret_stoch(latest['stoch_k'], latest['stoch_d'])
            },
            "adx": {
                "value": float(latest['adx']),
                "trend_strength": self._interpret_adx(latest['adx'])
            }
        }
    
    def _detect_patterns(self, df: pd.DataFrame) -> List[Dict[str, Any]]:
        """Detect candlestick and chart patterns"""
        patterns = []
        
        # Candlestick patterns
        df['doji'] = ta.cdl_doji(df['open'], df['high'], df['low'], df['close'])
        df['hammer'] = ta.cdl_hammer(df['open'], df['high'], df['low'], df['close'])
        df['engulfing'] = ta.cdl_engulfing(df['open'], df['high'], df['low'], df['close'])
        
        latest = df.iloc[-1]
        
        if latest['doji'] != 0:
            patterns.append({
                "name": "Doji",
                "type": "indecision",
                "significance": "high",
                "description": "Market indecision, potential reversal"
            })
        
        if latest['hammer'] != 0:
            patterns.append({
                "name": "Hammer",
                "type": "bullish_reversal",
                "significance": "high",
                "description": "Bullish reversal pattern at support"
            })
        
        if latest['engulfing'] != 0:
            patterns.append({
                "name": "Engulfing",
                "type": "reversal",
                "significance": "very_high",
                "description": "Strong reversal signal"
            })
        
        # Chart patterns (simplified detection)
        if self._is_double_top(df):
            patterns.append({
                "name": "Double Top",
                "type": "bearish_reversal",
                "significance": "high",
                "description": "Bearish reversal pattern forming"
            })
        
        if self._is_double_bottom(df):
            patterns.append({
                "name": "Double Bottom",
                "type": "bullish_reversal",
                "significance": "high",
                "description": "Bullish reversal pattern forming"
            })
        
        return patterns
    
    def _analyze_trend(
        self, 
        df: pd.DataFrame, 
        indicators: Dict[str, Any]
    ) -> Dict[str, Any]:
        """Analyze current market trend"""
        
        latest = df.iloc[-1]
        
        # Price vs Moving Averages
        price = latest['close']
        sma_20 = indicators['moving_averages']['sma_20']
        sma_50 = indicators['moving_averages']['sma_50']
        
        # Determine trend direction
        if price > sma_20 > sma_50:
            direction = "strong_uptrend"
            strength = 0.8
        elif price > sma_20:
            direction = "uptrend"
            strength = 0.6
        elif price < sma_20 < sma_50:
            direction = "strong_downtrend"
            strength = 0.8
        elif price < sma_20:
            direction = "downtrend"
            strength = 0.6
        else:
            direction = "sideways"
            strength = 0.3
        
        # ADX confirmation
        adx = indicators['adx']['value']
        if adx > 25:
            strength *= 1.2  # Increase confidence
        
        return {
            "direction": direction,
            "strength": min(strength, 1.0),
            "momentum": self._calculate_momentum(df),
            "adx_confirmation": adx > 25
        }
    
    def _find_support_resistance(self, df: pd.DataFrame) -> Dict[str, List[float]]:
        """Find key support and resistance levels"""
        
        # Using pivot points
        highs = df['high'].tail(20).values
        lows = df['low'].tail(20).values
        
        resistance_levels = []
        support_levels = []
        
        # Find local maxima (resistance)
        for i in range(1, len(highs) - 1):
            if highs[i] > highs[i-1] and highs[i] > highs[i+1]:
                resistance_levels.append(float(highs[i]))
        
        # Find local minima (support)
        for i in range(1, len(lows) - 1):
            if lows[i] < lows[i-1] and lows[i] < lows[i+1]:
                support_levels.append(float(lows[i]))
        
        # Sort and take top 3
        resistance_levels = sorted(list(set(resistance_levels)), reverse=True)[:3]
        support_levels = sorted(list(set(support_levels)))[:3]
        
        return {
            "resistance": resistance_levels,
            "support": support_levels
        }
    
    def _analyze_sentiment(
        self, 
        df: pd.DataFrame, 
        indicators: Dict[str, Any]
    ) -> Dict[str, Any]:
        """Analyze market sentiment"""
        
        bullish_signals = 0
        bearish_signals = 0
        
        # RSI
        rsi = indicators['rsi']['value']
        if rsi < 30:
            bullish_signals += 2  # Oversold
        elif rsi > 70:
            bearish_signals += 2  # Overbought
        
        # MACD
        if indicators['macd']['histogram'] > 0:
            bullish_signals += 1
        else:
            bearish_signals += 1
        
        # Stochastic
        if indicators['stochastic']['k'] < 20:
            bullish_signals += 1
        elif indicators['stochastic']['k'] > 80:
            bearish_signals += 1
        
        # Moving Average trend
        ma_trend = indicators['moving_averages']['trend']
        if ma_trend == "bullish":
            bullish_signals += 2
        elif ma_trend == "bearish":
            bearish_signals += 2
        
        total_signals = bullish_signals + bearish_signals
        
        if total_signals == 0:
            sentiment = "neutral"
            score = 0.5
        else:
            score = bullish_signals / total_signals
            if score > 0.6:
                sentiment = "bullish"
            elif score < 0.4:
                sentiment = "bearish"
            else:
                sentiment = "neutral"
        
        return {
            "sentiment": sentiment,
            "score": score,
            "bullish_signals": bullish_signals,
            "bearish_signals": bearish_signals
        }
    
    def _generate_recommendation(
        self,
        trend: Dict[str, Any],
        indicators: Dict[str, Any],
        patterns: List[Dict[str, Any]],
        sentiment: Dict[str, Any]
    ) -> Dict[str, Any]:
        """Generate trading recommendation"""
        
        # Scoring system
        bullish_score = 0
        bearish_score = 0
        
        # Trend analysis
        if "uptrend" in trend["direction"]:
            bullish_score += trend["strength"] * 3
        elif "downtrend" in trend["direction"]:
            bearish_score += trend["strength"] * 3
        
        # Sentiment
        if sentiment["sentiment"] == "bullish":
            bullish_score += sentiment["score"] * 2
        elif sentiment["sentiment"] == "bearish":
            bearish_score += (1 - sentiment["score"]) * 2
        
        # Patterns
        for pattern in patterns:
            if "bullish" in pattern["type"]:
                bullish_score += 1
            elif "bearish" in pattern["type"]:
                bearish_score += 1
        
        # RSI
        rsi = indicators['rsi']['value']
        if rsi < 30:
            bullish_score += 1.5
        elif rsi > 70:
            bearish_score += 1.5
        
        # Determine action
        total_score = bullish_score + bearish_score
        if total_score == 0:
            action = "hold"
            confidence = 0.5
        else:
            confidence = max(bullish_score, bearish_score) / total_score
            
            if bullish_score > bearish_score and confidence > 0.6:
                action = "buy"
            elif bearish_score > bullish_score and confidence > 0.6:
                action = "sell"
            else:
                action = "hold"
        
        # Risk assessment
        atr = indicators['atr']['value']
        volatility = indicators['atr']['volatility']
        
        if volatility == "high":
            risk_level = "high"
        elif volatility == "medium":
            risk_level = "medium"
        else:
            risk_level = "low"
        
        return {
            "action": action,
            "confidence": round(confidence, 2),
            "risk_level": risk_level,
            "entry_points": self._suggest_entry_points(indicators),
            "stop_loss": self._suggest_stop_loss(indicators, action),
            "take_profit": self._suggest_take_profit(indicators, action)
        }
    
    # Helper methods
    def _interpret_rsi(self, rsi: float) -> str:
        if rsi < 30:
            return "oversold"
        elif rsi > 70:
            return "overbought"
        else:
            return "neutral"
    
    def _interpret_macd(self, latest) -> str:
        if latest['macd'] > latest['macd_signal']:
            return "bullish"
        else:
            return "bearish"
    
    def _bb_position(self, latest) -> str:
        close = latest['close']
        if close > latest['bb_upper']:
            return "above_upper"
        elif close < latest['bb_lower']:
            return "below_lower"
        else:
            return "within_bands"
    
    def _ma_trend(self, latest) -> str:
        close = latest['close']
        sma_20 = latest['sma_20']
        sma_50 = latest['sma_50']
        
        if close > sma_20 > sma_50:
            return "bullish"
        elif close < sma_20 < sma_50:
            return "bearish"
        else:
            return "neutral"
    
    def _interpret_atr(self, atr: float, price: float) -> str:
        atr_percent = (atr / price) * 100
        if atr_percent > 2:
            return "high"
        elif atr_percent > 1:
            return "medium"
        else:
            return "low"
    
    def _interpret_stoch(self, k: float, d: float) -> str:
        if k < 20 and d < 20:
            return "oversold"
        elif k > 80 and d > 80:
            return "overbought"
        else:
            return "neutral"
    
    def _interpret_adx(self, adx: float) -> str:
        if adx > 25:
            return "strong"
        elif adx > 20:
            return "moderate"
        else:
            return "weak"
    
    def _calculate_momentum(self, df: pd.DataFrame) -> float:
        """Calculate price momentum"""
        returns = df['close'].pct_change().tail(10)
        return float(returns.mean() * 100)
    
    def _is_double_top(self, df: pd.DataFrame) -> bool:
        """Simplified double top detection"""
        highs = df['high'].tail(20).values
        if len(highs) < 10:
            return False
        # Implement proper double top detection logic
        return False
    
    def _is_double_bottom(self, df: pd.DataFrame) -> bool:
        """Simplified double bottom detection"""
        lows = df['low'].tail(20).values
        if len(lows) < 10:
            return False
        # Implement proper double bottom detection logic
        return False
    
    def _suggest_entry_points(self, indicators: Dict[str, Any]) -> List[float]:
        """Suggest potential entry points"""
        bb_middle = indicators['bollinger_bands']['middle']
        bb_lower = indicators['bollinger_bands']['lower']
        
        return [
            round(bb_middle, 5),
            round(bb_lower, 5)
        ]
    
    def _suggest_stop_loss(self, indicators: Dict[str, Any], action: str) -> float:
        """Suggest stop loss level"""
        atr = indicators['atr']['value']
        bb_middle = indicators['bollinger_bands']['middle']
        
        if action == "buy":
            return round(bb_middle - (2 * atr), 5)
        else:
            return round(bb_middle + (2 * atr), 5)
    
    def _suggest_take_profit(self, indicators: Dict[str, Any], action: str) -> float:
        """Suggest take profit level"""
        atr = indicators['atr']['value']
        bb_middle = indicators['bollinger_bands']['middle']
        
        if action == "buy":
            return round(bb_middle + (3 * atr), 5)
        else:
            return round(bb_middle - (3 * atr), 5)
