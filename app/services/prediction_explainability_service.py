"""
Prediction Explainability & Transparency Service
Provides detailed reasoning behind AI predictions and trading decisions
"""
from dataclasses import dataclass, field
from datetime import datetime
from typing import Dict, List, Optional, Tuple
from enum import Enum


class SentimentType(Enum):
    """Market sentiment classification"""
    BULLISH = "bullish"
    NEUTRAL = "neutral"
    BEARISH = "bearish"


class NewsImpact(Enum):
    """News impact severity"""
    LOW = "low"
    MEDIUM = "medium"
    HIGH = "high"


@dataclass
class TechnicalIndicator:
    """Technical indicator analysis"""
    name: str  # RSI, MACD, EMA, SMA, Bollinger Bands, etc.
    value: float
    threshold_buy: float
    threshold_sell: float
    signal: str  # "BUY", "SELL", "HOLD"
    weight: float = 1.0  # Importance in overall prediction


@dataclass
class PredictionExplanation:
    """Complete explanation of a prediction"""
    prediction_id: str
    pair: str
    action: str  # BUY, SELL, HOLD
    confidence_score: float  # 0-100%
    timestamp: datetime
    
    # Sentiment
    sentiment: SentimentType
    sentiment_score: float  # -1.0 (bearish) to +1.0 (bullish)
    
    # Technical indicators
    indicators: List[TechnicalIndicator]
    indicators_bullish: int
    indicators_bearish: int
    indicators_neutral: int
    
    # News & Events
    upcoming_events: List[str]
    news_impact: NewsImpact
    
    # Support & Resistance
    support_level: float
    resistance_level: float
    support_proximity: str  # "far", "moderate", "near"
    
    # Reasoning summary
    key_reasons: List[str]
    risk_factors: List[str]
    bullish_factors: List[str]
    bearish_factors: List[str]
    
    # Prediction history context
    past_accuracy_similar_conditions: float  # Historical accuracy %
    convergence_strength: float  # 0-100%, how many signals agree
    
    # Optional fields (with defaults)
    recent_news: List[Dict] = field(default_factory=list)


@dataclass
class PredictionAccuracyTracker:
    """Track prediction accuracy over time"""
    prediction_id: str
    pair: str
    action: str
    predicted_price: float
    predicted_time: datetime
    actual_entry_price: float
    actual_exit_price: Optional[float] = None
    actual_time: Optional[datetime] = None
    was_profitable: Optional[bool] = None
    accuracy_percentage: Optional[float] = None  # Distance from actual


class PredictionExplainabilityService:
    """
    Service to explain AI predictions with transparency
    Builds user confidence through detailed reasoning
    """
    
    def __init__(self):
        self.predictions_history: List[PredictionExplanation] = []
        self.accuracy_tracker: Dict[str, List[PredictionAccuracyTracker]] = {}
        self.pair_win_rates: Dict[str, Dict] = {}

    async def generate_prediction_explanation(
        self,
        pair: str,
        action: str,
        technical_indicators: List[Dict],
        sentiment_data: Dict,
        news_data: Dict,
        support_resistance: Dict,
        confidence_score: float
    ) -> PredictionExplanation:
        """
        Generate detailed explanation for a trading prediction
        """
        
        # Process technical indicators
        indicators = []
        bullish_count = 0
        bearish_count = 0
        neutral_count = 0
        
        for ind_data in technical_indicators:
            indicator = TechnicalIndicator(
                name=ind_data.get("name"),
                value=ind_data.get("value", 0),
                threshold_buy=ind_data.get("threshold_buy", 50),
                threshold_sell=ind_data.get("threshold_sell", 50),
                signal=ind_data.get("signal", "HOLD"),
                weight=ind_data.get("weight", 1.0)
            )
            indicators.append(indicator)
            
            if indicator.signal == "BUY":
                bullish_count += 1
            elif indicator.signal == "SELL":
                bearish_count += 1
            else:
                neutral_count += 1
        
        # Process sentiment
        sentiment_value = sentiment_data.get("score", 0)  # -1 to +1
        if sentiment_value > 0.2:
            sentiment = SentimentType.BULLISH
        elif sentiment_value < -0.2:
            sentiment = SentimentType.BEARISH
        else:
            sentiment = SentimentType.NEUTRAL
        
        # Process news impact
        news_count = len(news_data.get("events", []))
        high_impact_news = len([n for n in news_data.get("events", []) if n.get("impact") == "high"])
        
        if high_impact_news >= 2:
            news_impact = NewsImpact.HIGH
        elif high_impact_news >= 1 or news_count >= 3:
            news_impact = NewsImpact.MEDIUM
        else:
            news_impact = NewsImpact.LOW
        
        # Build key reasons
        key_reasons = self._build_key_reasons(
            action, bullish_count, bearish_count, sentiment, 
            news_impact, support_resistance
        )
        
        # Build risk factors
        risk_factors = self._identify_risk_factors(
            pair, sentiment, news_impact, support_resistance
        )
        
        # Calculate convergence strength
        convergence = self._calculate_convergence(
            bullish_count, bearish_count, neutral_count,
            sentiment, news_impact
        )
        
        # Get historical accuracy
        historical_accuracy = await self._get_historical_accuracy(pair, action)
        
        # Create explanation
        prediction_id = f"pred_{pair}_{datetime.now().timestamp()}"
        explanation = PredictionExplanation(
            prediction_id=prediction_id,
            pair=pair,
            action=action,
            confidence_score=confidence_score,
            timestamp=datetime.now(),
            sentiment=sentiment,
            sentiment_score=sentiment_value,
            indicators=indicators,
            indicators_bullish=bullish_count,
            indicators_bearish=bearish_count,
            indicators_neutral=neutral_count,
            upcoming_events=news_data.get("upcoming", []),
            news_impact=news_impact,
            recent_news=news_data.get("events", []),
            support_level=support_resistance.get("support", 0),
            resistance_level=support_resistance.get("resistance", 0),
            support_proximity=self._calculate_proximity(
                support_resistance.get("current_price", 0),
                support_resistance.get("support", 0),
                support_resistance.get("resistance", 0)
            ),
            key_reasons=key_reasons,
            risk_factors=risk_factors,
            bullish_factors=self._extract_bullish_factors(indicators, sentiment, news_data),
            bearish_factors=self._extract_bearish_factors(indicators, sentiment, news_data),
            past_accuracy_similar_conditions=historical_accuracy,
            convergence_strength=convergence
        )
        
        # Store for history
        self.predictions_history.append(explanation)
        
        return explanation

    def _build_key_reasons(self, action: str, bullish: int, bearish: int, 
                          sentiment: SentimentType, news_impact: NewsImpact,
                          support_resistance: Dict) -> List[str]:
        """Build list of key reasons for the prediction"""
        reasons = []
        
        if action == "BUY":
            if bullish > bearish:
                reasons.append(f"Technical indicators show {bullish} bullish signals vs {bearish} bearish")
            if sentiment == SentimentType.BULLISH:
                reasons.append("Market sentiment is bullish with positive momentum")
            if support_resistance.get("near_support"):
                reasons.append("Price near strong support level - good entry point")
            if news_impact == NewsImpact.LOW:
                reasons.append("No major economic news in next 24 hours - stable conditions")
        
        elif action == "SELL":
            if bearish > bullish:
                reasons.append(f"Technical indicators show {bearish} bearish signals vs {bullish} bullish")
            if sentiment == SentimentType.BEARISH:
                reasons.append("Market sentiment is bearish with downward pressure")
            if support_resistance.get("near_resistance"):
                reasons.append("Price near resistance level - good exit opportunity")
            if news_impact == NewsImpact.HIGH:
                reasons.append("High-impact economic news expected - prepare for volatility")
        
        return reasons if reasons else ["Neutral technical picture with no strong directional bias"]

    def _identify_risk_factors(self, pair: str, sentiment: SentimentType, 
                              news_impact: NewsImpact, support_resistance: Dict) -> List[str]:
        """Identify potential risk factors"""
        risks = []
        
        if sentiment == SentimentType.NEUTRAL:
            risks.append("Mixed sentiment - market indecision may lead to whipsaws")
        
        if news_impact == NewsImpact.HIGH:
            risks.append("High-impact economic news approaching - expect volatility")
        
        if support_resistance.get("wide_range"):
            risks.append("Wide price range - potential for false breakouts")
        
        if "JPY" in pair or "GBP" in pair:
            risks.append(f"{pair} can be volatile - consider tighter stop losses")
        
        risks.append("Past performance does not guarantee future results")
        
        return risks

    def _extract_bullish_factors(self, indicators: List[TechnicalIndicator],
                                sentiment: SentimentType, news_data: Dict) -> List[str]:
        """Extract bullish factors"""
        factors = []
        
        bullish_indicators = [i.name for i in indicators if i.signal == "BUY"]
        if bullish_indicators:
            factors.append(f"Bullish signals: {', '.join(bullish_indicators)}")
        
        if sentiment == SentimentType.BULLISH:
            factors.append("Bullish market sentiment")
        
        if news_data.get("major_positive"):
            factors.append("Positive economic developments")
        
        return factors

    def _extract_bearish_factors(self, indicators: List[TechnicalIndicator],
                                sentiment: SentimentType, news_data: Dict) -> List[str]:
        """Extract bearish factors"""
        factors = []
        
        bearish_indicators = [i.name for i in indicators if i.signal == "SELL"]
        if bearish_indicators:
            factors.append(f"Bearish signals: {', '.join(bearish_indicators)}")
        
        if sentiment == SentimentType.BEARISH:
            factors.append("Bearish market sentiment")
        
        if news_data.get("major_negative"):
            factors.append("Negative economic developments")
        
        return factors

    def _calculate_convergence(self, bullish: int, bearish: int, neutral: int,
                              sentiment: SentimentType, news_impact: NewsImpact) -> float:
        """
        Calculate how strongly indicators converge
        Higher = more signals agree
        """
        total = bullish + bearish + neutral
        if total == 0:
            return 50.0
        
        convergence = max(bullish, bearish) / total * 100
        
        # Boost convergence if sentiment and indicators agree
        if sentiment == SentimentType.BULLISH and bullish > bearish:
            convergence = min(100, convergence + 10)
        elif sentiment == SentimentType.BEARISH and bearish > bullish:
            convergence = min(100, convergence + 10)
        
        return convergence

    def _calculate_proximity(self, current: float, support: float, resistance: float) -> str:
        """Calculate proximity to support/resistance"""
        if current <= 0:
            return "unknown"
        
        to_support = abs(current - support) / current * 100
        to_resistance = abs(current - resistance) / current * 100
        min_distance = min(to_support, to_resistance)
        
        if min_distance < 0.5:
            return "near"
        elif min_distance < 1.0:
            return "moderate"
        else:
            return "far"

    async def _get_historical_accuracy(self, pair: str, action: str) -> float:
        """Get historical accuracy for this pair/action combination"""
        if pair not in self.pair_win_rates:
            return 50.0  # Default neutral
        
        rates = self.pair_win_rates[pair]
        if action == "BUY":
            return rates.get("buy_accuracy", 50.0)
        else:
            return rates.get("sell_accuracy", 50.0)

    async def record_prediction_outcome(self, prediction_id: str, 
                                       actual_entry: float, 
                                       actual_exit: Optional[float] = None) -> Dict:
        """Record actual outcome of a prediction"""
        prediction = next((p for p in self.predictions_history if p.prediction_id == prediction_id), None)
        
        if not prediction:
            return {"error": "Prediction not found"}
        
        tracker = PredictionAccuracyTracker(
            prediction_id=prediction_id,
            pair=prediction.pair,
            action=prediction.action,
            predicted_price=0,  # Would need entry price from prediction
            predicted_time=prediction.timestamp,
            actual_entry_price=actual_entry,
            actual_exit_price=actual_exit,
            actual_time=datetime.now()
        )
        
        if prediction.pair not in self.accuracy_tracker:
            self.accuracy_tracker[prediction.pair] = []
        self.accuracy_tracker[prediction.pair].append(tracker)
        
        return {"success": True, "message": "Prediction outcome recorded"}

    async def get_prediction_history(self, pair: Optional[str] = None, limit: int = 10) -> Dict:
        """Get prediction history with formatting"""
        history = self.predictions_history
        
        if pair:
            history = [p for p in history if p.pair == pair]
        
        history = history[-limit:]  # Most recent
        
        return {
            "predictions": [
                {
                    "prediction_id": p.prediction_id,
                    "pair": p.pair,
                    "action": p.action,
                    "confidence": f"{p.confidence_score:.1f}%",
                    "sentiment": p.sentiment.value,
                    "key_reasons": p.key_reasons,
                    "indicators": {
                        "bullish": p.indicators_bullish,
                        "bearish": p.indicators_bearish,
                        "neutral": p.indicators_neutral,
                    },
                    "convergence": f"{p.convergence_strength:.1f}%",
                    "timestamp": p.timestamp.isoformat()
                }
                for p in history
            ]
        }

    async def get_detailed_explanation(self, prediction_id: str) -> Dict:
        """Get detailed explanation panel for a prediction"""
        prediction = next((p for p in self.predictions_history if p.prediction_id == prediction_id), None)
        
        if not prediction:
            return {"error": "Prediction not found"}
        
        return {
            "prediction_id": prediction_id,
            "why_this_trade": {
                "key_reasons": prediction.key_reasons,
                "bullish_factors": prediction.bullish_factors,
                "bearish_factors": prediction.bearish_factors,
            },
            "sentiment": {
                "classification": prediction.sentiment.value.upper(),
                "score": f"{prediction.sentiment_score:.2f}",
                "interpretation": "Strong uptrend expected" if prediction.sentiment == SentimentType.BULLISH else "Downtrend likely" if prediction.sentiment == SentimentType.BEARISH else "No clear direction"
            },
            "technical_indicators": [
                {
                    "name": ind.name,
                    "value": f"{ind.value:.2f}",
                    "signal": ind.signal,
                    "weight": f"{ind.weight:.1f}",
                }
                for ind in prediction.indicators
            ],
            "news_analysis": {
                "impact": prediction.news_impact.value.upper(),
                "upcoming_events": prediction.upcoming_events,
                "recent_news": prediction.recent_news[:3]  # Last 3 news items
            },
            "support_resistance": {
                "support": f"{prediction.support_level:.4f}",
                "resistance": f"{prediction.resistance_level:.4f}",
                "proximity": prediction.support_proximity,
            },
            "confidence": {
                "score": f"{prediction.confidence_score:.1f}%",
                "convergence": f"{prediction.convergence_strength:.1f}%",
                "historical_accuracy": f"{prediction.past_accuracy_similar_conditions:.1f}%",
            },
            "risk_factors": prediction.risk_factors,
            "timestamp": prediction.timestamp.isoformat()
        }

    async def get_accuracy_report(self, pair: Optional[str] = None, days: int = 30) -> Dict:
        """Get prediction accuracy report"""
        trackers = []
        
        if pair:
            trackers = self.accuracy_tracker.get(pair, [])
        else:
            trackers = [t for trackers_list in self.accuracy_tracker.values() for t in trackers_list]
        
        if not trackers:
            return {"message": "No completed predictions to analyze"}
        
        total = len(trackers)
        profitable = len([t for t in trackers if t.was_profitable])
        win_rate = (profitable / total * 100) if total > 0 else 0
        
        return {
            "summary": {
                "total_predictions": total,
                "profitable": profitable,
                "losing": total - profitable,
                "win_rate": f"{win_rate:.1f}%",
            },
            "by_pair": self._group_by_pair(trackers),
            "by_action": self._group_by_action(trackers),
            "trend": "Accuracy improving" if win_rate > 55 else "Needs improvement" if win_rate < 45 else "Neutral"
        }

    def _group_by_pair(self, trackers: List[PredictionAccuracyTracker]) -> Dict:
        """Group accuracy by currency pair"""
        grouped = {}
        for tracker in trackers:
            if tracker.pair not in grouped:
                grouped[tracker.pair] = {"profitable": 0, "total": 0}
            grouped[tracker.pair]["total"] += 1
            if tracker.was_profitable:
                grouped[tracker.pair]["profitable"] += 1
        
        return {pair: (data["profitable"] / data["total"] * 100) for pair, data in grouped.items()}

    def _group_by_action(self, trackers: List[PredictionAccuracyTracker]) -> Dict:
        """Group accuracy by action (BUY/SELL)"""
        grouped = {"BUY": {"profitable": 0, "total": 0}, "SELL": {"profitable": 0, "total": 0}}
        for tracker in trackers:
            grouped[tracker.action]["total"] += 1
            if tracker.was_profitable:
                grouped[tracker.action]["profitable"] += 1
        
        return {
            action: (data["profitable"] / data["total"] * 100) if data["total"] > 0 else 0 
            for action, data in grouped.items()
        }
