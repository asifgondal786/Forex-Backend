"""
Forex Data Service - Fetches real-time data from multiple sources
Integrates with Google Generative AI (Gemini) for market analysis and predictions
"""
import asyncio
import aiohttp
from datetime import datetime
from typing import Any, Dict, List, Optional
import os
import time
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


class ForexDataService:
    """Service to fetch real-time forex data from multiple sources"""

    def __init__(self):
        self.session: Optional[aiohttp.ClientSession] = None
        self.running = False
        self._latest_rates: Dict[str, float] = {}
        self._latest_usd_base_rates: Dict[str, float] = {}
        self._price_history: Dict[str, List[float]] = {}
        self._last_rates_fetch_monotonic = 0.0
        self._rate_failure_streak = 0
        self._next_rates_retry_monotonic = 0.0
        self._last_rates_error_log_monotonic = 0.0
        self._last_rates_error_text = ""
        try:
            self._min_rates_fetch_interval_seconds = max(
                1,
                int(os.getenv("FOREX_RATES_MIN_FETCH_INTERVAL_SECONDS", "3")),
            )
        except Exception:
            self._min_rates_fetch_interval_seconds = 3

    async def initialize(self):
        """Initialize the HTTP session"""
        if not self.session or self.session.closed:
            connector = aiohttp.TCPConnector(
                limit=20,
                ttl_dns_cache=300,
                enable_cleanup_closed=True,
            )
            timeout = aiohttp.ClientTimeout(total=12, connect=5, sock_connect=5, sock_read=10)
            self.session = aiohttp.ClientSession(connector=connector, timeout=timeout)

    async def close(self):
        """Close the HTTP session"""
        if self.session:
            await self.session.close()
            self.session = None

    async def get_forex_factory_news(self) -> List[Dict]:
        """
        Fetch news from Forex Factory calendar
        Note: This is a simplified version. Real implementation would need web scraping.
        """
        try:
            # For production, you'd use web scraping or a paid API.
            # For now, we'll simulate with structured data.
            return [
                {
                    "time": datetime.now().isoformat(),
                    "currency": "USD",
                    "impact": "high",
                    "event": "Non-Farm Payrolls",
                    "actual": "N/A",
                    "forecast": "180K",
                    "previous": "199K"
                },
                {
                    "time": datetime.now().isoformat(),
                    "currency": "EUR",
                    "impact": "medium",
                    "event": "ECB Interest Rate Decision",
                    "actual": "N/A",
                    "forecast": "4.50%",
                    "previous": "4.50%"
                }
            ]
        except Exception as e:
            print(f"Error fetching Forex Factory news: {e}")
            return []

    async def get_currency_rates(self) -> Dict[str, float]:
        """
        Fetch real-time currency exchange rates
        Using exchangerate-api.com (free tier)
        """
        now = time.monotonic()
        if (
            self._latest_rates
            and (now - self._last_rates_fetch_monotonic) < self._min_rates_fetch_interval_seconds
        ):
            return dict(self._latest_rates)

        if now < self._next_rates_retry_monotonic and self._latest_rates:
            return dict(self._latest_rates)

        try:
            # Free API - no key required for basic usage
            url = "https://api.exchangerate-api.com/v4/latest/USD"

            if not self.session:
                await self.initialize()

            async with self.session.get(url) as response:
                if response.status == 200:
                    data = await response.json()
                    rates = data.get("rates", {})
                    usd_base = {}
                    for code, value in rates.items():
                        if isinstance(value, (int, float)) and value > 0:
                            usd_base[str(code).upper()] = float(value)

                    self._latest_usd_base_rates = usd_base

                    parsed_rates = {
                        "EUR/USD": (1 / usd_base["EUR"]) if usd_base.get("EUR") else None,
                        "GBP/USD": (1 / usd_base["GBP"]) if usd_base.get("GBP") else None,
                        "USD/JPY": usd_base.get("JPY"),
                        "USD/CHF": usd_base.get("CHF"),
                        "AUD/USD": (1 / usd_base["AUD"]) if usd_base.get("AUD") else None,
                        "USD/CAD": usd_base.get("CAD"),
                        "NZD/USD": (1 / usd_base["NZD"]) if usd_base.get("NZD") else None,
                        "USD/PKR": usd_base.get("PKR"),
                    }
                    clean_rates = {
                        pair: float(price)
                        for pair, price in parsed_rates.items()
                        if isinstance(price, (int, float)) and price > 0
                    }
                    if clean_rates:
                        self._latest_rates = dict(clean_rates)
                        self._update_price_history(clean_rates)
                        self._last_rates_fetch_monotonic = now
                        self._rate_failure_streak = 0
                        self._next_rates_retry_monotonic = 0.0
                    return clean_rates

                self._record_rates_fetch_error(
                    f"HTTP {response.status} from exchangerate-api.com"
                )
        except Exception as e:
            self._record_rates_fetch_error(str(e))
            if self._latest_rates:
                return dict(self._latest_rates)
            return {
                "EUR/USD": 1.08,
                "GBP/USD": 1.27,
                "USD/JPY": 154.0,
                "USD/CHF": 0.78,
                "AUD/USD": 0.66,
                "USD/CAD": 1.37,
                "NZD/USD": 0.60,
                "USD/PKR": 279.0,
            }

        if self._latest_rates:
            return dict(self._latest_rates)
        return {
            "EUR/USD": 1.08,
            "GBP/USD": 1.27,
            "USD/JPY": 154.0,
            "USD/CHF": 0.78,
            "AUD/USD": 0.66,
            "USD/CAD": 1.37,
            "NZD/USD": 0.60,
            "USD/PKR": 279.0,
        }

    def _record_rates_fetch_error(self, error_text: str) -> None:
        now = time.monotonic()
        self._rate_failure_streak += 1
        backoff_seconds = float(min(90, 2 ** min(self._rate_failure_streak, 6)))
        self._next_rates_retry_monotonic = now + backoff_seconds

        should_log = (
            error_text != self._last_rates_error_text
            or (now - self._last_rates_error_log_monotonic) >= 30
        )
        if should_log:
            print(
                f"Error fetching currency rates: {error_text}. "
                f"Retry backoff: {int(backoff_seconds)}s"
            )
            self._last_rates_error_text = error_text
            self._last_rates_error_log_monotonic = now

    def _normalize_pair(self, pair: str) -> str:
        cleaned = str(pair or "").strip().upper().replace("-", "/").replace(" ", "")
        if "/" in cleaned:
            return cleaned
        if len(cleaned) == 6:
            return f"{cleaned[:3]}/{cleaned[3:]}"
        return cleaned

    def _pair_digits(self, pair: str) -> int:
        pair_upper = pair.upper()
        if "JPY" in pair_upper or "PKR" in pair_upper:
            return 2
        return 4

    def _update_price_history(self, rates: Dict[str, float]) -> None:
        for pair, price in rates.items():
            history = self._price_history.setdefault(pair, [])
            history.append(float(price))
            if len(history) > 240:
                del history[:-240]

    def _derive_pair_from_usd_table(self, pair: str) -> Optional[float]:
        if "/" not in pair:
            return None
        base, quote = pair.split("/", 1)
        base = base.strip().upper()
        quote = quote.strip().upper()
        table = self._latest_usd_base_rates
        if not table:
            return None

        if base == quote:
            return 1.0
        if base == "USD":
            value = table.get(quote)
            return float(value) if isinstance(value, (int, float)) and value > 0 else None
        if quote == "USD":
            base_rate = table.get(base)
            if isinstance(base_rate, (int, float)) and base_rate > 0:
                return 1.0 / float(base_rate)
            return None

        base_rate = table.get(base)
        quote_rate = table.get(quote)
        if (
            isinstance(base_rate, (int, float))
            and isinstance(quote_rate, (int, float))
            and base_rate > 0
            and quote_rate > 0
        ):
            return float(quote_rate) / float(base_rate)
        return None

    def _normalize_horizon(self, horizon: str) -> str:
        value = str(horizon or "").strip().lower()
        if value in {"intraday", "intra", "4h", "6h", "12h", "today"}:
            return "intraday"
        if value in {"1w", "week", "weekly", "7d", "7day"}:
            return "1w"
        return "1d"

    async def get_pair_forecast(self, pair: str, horizon: str = "1d") -> Dict[str, Any]:
        """
        Produce a structured near-term forecast with horizon and confidence.
        """
        normalized_pair = self._normalize_pair(pair)
        normalized_horizon = self._normalize_horizon(horizon)

        rates = await self.get_currency_rates()
        current_price = rates.get(normalized_pair)
        if current_price is None:
            derived = self._derive_pair_from_usd_table(normalized_pair)
            if derived is not None:
                current_price = float(derived)
                rates[normalized_pair] = current_price
                self._latest_rates[normalized_pair] = current_price
                self._update_price_history({normalized_pair: current_price})

        if current_price is None or current_price <= 0:
            raise ValueError(f"Pair {normalized_pair} is not available for forecasting")

        news = await self.get_forex_factory_news()
        sentiment = await self.analyze_market_with_gemini(rates, news)
        trend = str(sentiment.get("trend", "neutral")).lower()
        volatility = str(sentiment.get("volatility", "medium")).lower()
        risk_level = str(sentiment.get("risk_level", "moderate")).lower()

        history = self._price_history.get(normalized_pair, [])
        lookback = 8 if normalized_horizon == "intraday" else 20 if normalized_horizon == "1d" else 60
        if len(history) >= 2:
            anchor_price = history[-lookback] if len(history) >= lookback else history[0]
            latest_prev = history[-2]
            momentum_pct = (
                ((history[-1] - anchor_price) / anchor_price) * 100
                if anchor_price
                else 0.0
            )
            latest_change_pct = (
                ((history[-1] - latest_prev) / latest_prev) * 100
                if latest_prev
                else 0.0
            )
        else:
            momentum_pct = 0.0
            latest_change_pct = 0.0

        trend_score = 1.0 if "bull" in trend else -1.0 if "bear" in trend else 0.0
        momentum_score = 1.0 if momentum_pct > 0.05 else -1.0 if momentum_pct < -0.05 else 0.0
        combined_bias_score = (trend_score * 0.65) + (momentum_score * 0.35)
        if abs(combined_bias_score) < 0.15:
            if latest_change_pct > 0.02:
                combined_bias_score = 0.18
            elif latest_change_pct < -0.02:
                combined_bias_score = -0.18

        trend_bias = "bullish" if combined_bias_score > 0.2 else "bearish" if combined_bias_score < -0.2 else "neutral"
        horizon_base = {
            "intraday": 0.25,
            "1d": 0.55,
            "1w": 1.60,
        }[normalized_horizon]
        volatility_multiplier = 1.6 if "high" in volatility else 0.7 if "low" in volatility else 1.0
        risk_multiplier = 0.85 if "high" in risk_level else 1.05 if "low" in risk_level else 1.0
        expected_mid_pct = horizon_base * volatility_multiplier * risk_multiplier * combined_bias_score
        spread_pct = horizon_base * (1.05 if "high" in volatility else 0.75)
        expected_low_pct = expected_mid_pct - spread_pct
        expected_high_pct = expected_mid_pct + spread_pct

        target_low = current_price * (1 + (expected_low_pct / 100))
        target_high = current_price * (1 + (expected_high_pct / 100))

        history_strength = min(len(history) / 40.0, 1.0)
        direction_alignment = (
            1.0 if trend_score == momentum_score and trend_score != 0 else
            0.6 if trend_score == 0 or momentum_score == 0 else
            0.35
        )
        confidence = int(round(
            max(
                45.0,
                min(
                    92.0,
                    50.0 + (history_strength * 22.0) + (direction_alignment * 18.0) -
                    (8.0 if "high" in volatility else 0.0),
                ),
            )
        ))

        digits = self._pair_digits(normalized_pair)
        if trend_bias == "bullish":
            timing_guidance = (
                f"Bias favors upside. Consider scaling out near {target_high:.{digits}f} and "
                f"protecting below {target_low:.{digits}f}."
            )
        elif trend_bias == "bearish":
            timing_guidance = (
                f"Bias is defensive. Prefer waiting for stabilization above {target_low:.{digits}f} "
                f"before adding exposure."
            )
        else:
            timing_guidance = (
                f"Bias is mixed. Favor partial exits around range extremes between "
                f"{target_low:.{digits}f} and {target_high:.{digits}f}."
            )

        return {
            "pair": normalized_pair,
            "horizon": normalized_horizon,
            "generated_at": datetime.now().isoformat(),
            "current_price": round(float(current_price), digits),
            "trend_bias": trend_bias,
            "volatility": volatility,
            "risk_level": risk_level,
            "confidence_percent": confidence,
            "expected_change_percent": {
                "low": round(expected_low_pct, 3),
                "mid": round(expected_mid_pct, 3),
                "high": round(expected_high_pct, 3),
            },
            "target_range": {
                "low": round(target_low, digits),
                "high": round(target_high, digits),
            },
            "timing_guidance": timing_guidance,
            "supporting_factors": [
                f"trend={trend}",
                f"volatility={volatility}",
                f"risk={risk_level}",
                f"momentum={momentum_pct:.3f}%",
            ],
            "disclaimer": "Simulation-grade forecast. Not financial advice.",
        }

    async def analyze_market_with_gemini(self, rates: Dict[str, float], news: List[Dict]) -> Dict[str, any]:
        """
        Use Google Generative AI (Gemini) to analyze market conditions from real-time data
        """
        try:
            if not GEMINI_AVAILABLE:
                return self.get_default_sentiment(rates)
                
            model = genai.GenerativeModel("gemini-2.0-flash")
            
            # Format news for analysis
            news_text = "\n".join([
                f"- {news_item['currency']}: {news_item['event']} (Impact: {news_item['impact']})"
                for news_item in news
            ])
            
            # Format rates for analysis
            rates_text = "\n".join([
                f"- {pair}: {rate:.5f}"
                for pair, rate in rates.items()
            ])
            
            prompt = f"""
            You are a professional forex market analyst with deep expertise in technical and fundamental analysis.
            
            Analyze the current forex market conditions:
            
            EXCHANGE RATES:
            {rates_text}
            
            ECONOMIC NEWS:
            {news_text}
            
            Please provide a comprehensive analysis including:
            1. Overall market sentiment (bullish, bearish, neutral)
            2. Volatility assessment (low, medium, high)
            3. Risk level (low, moderate, high)
            4. Key currency pairs to watch with reasoning
            5. Trading opportunities identification
            6. Potential market-moving factors
            
            Format your response as JSON with clear, actionable insights.
            """
            
            response = model.generate_content(prompt)
            
            import json
            try:
                analysis = json.loads(response.text)
                analysis["timestamp"] = datetime.now().isoformat()
                analysis["major_pairs"] = rates
            except:
                analysis = self.get_default_sentiment(rates)
                analysis["ai_analysis"] = response.text
                
            return analysis
            
        except Exception as e:
            print(f"Gemini analysis failed: {e}")
            return self.get_default_sentiment(rates)

    def get_default_sentiment(self, rates: Dict[str, float]) -> Dict[str, any]:
        """Fallback market sentiment analysis when AI is unavailable"""
        return {
            "timestamp": datetime.now().isoformat(),
            "trend": "bullish",
            "major_pairs": rates,
            "volatility": "medium",
            "risk_level": "moderate"
        }

    async def predict_price_movements(self, pair: str, historical_data: List[Dict]) -> Dict[str, any]:
        """
        Use Google Generative AI (Gemini) to predict future price movements
        """
        try:
            if not GEMINI_AVAILABLE:
                return {
                    "success": False,
                    "message": "Gemini is unavailable (missing package or API key)",
                    "prediction": None
                }
                
            model = genai.GenerativeModel("gemini-1.5-pro")
            
            # Format historical data for analysis
            data_text = "\n".join([
                f"- Time: {data['timestamp']}, Price: {data['close']:.5f}"
                for data in historical_data[-50:]  # Last 50 data points
            ])
            
            prompt = f"""
            You are an expert technical analyst specializing in forex price prediction.
            
            Predict the future price movement for {pair} using historical data:
            
            HISTORICAL DATA (Last 50 periods):
            {data_text}
            
            Please provide:
            1. Price direction prediction (up, down, sideways)
            2. Confidence level (0-100%)
            3. Target price levels (support, resistance)
            4. Timeframe for this prediction
            5. Technical indicators supporting this prediction
            6. Risk assessment
            
            Format your response as JSON.
            """
            
            response = model.generate_content(prompt)
            
            import json
            try:
                prediction = json.loads(response.text)
                prediction["pair"] = pair
                prediction["timestamp"] = datetime.now().isoformat()
            except:
                prediction = {
                    "direction": "neutral",
                    "confidence": 50,
                    "support": None,
                    "resistance": None,
                    "timeframe": "1H",
                    "indicators": ["Cannot parse structured response"],
                    "risk": "medium"
                }
                
            return {
                "success": True,
                "message": "Prediction generated successfully",
                "prediction": prediction
            }
            
        except Exception as e:
            return {
                "success": False,
                "message": f"Prediction failed: {str(e)}",
                "prediction": None
            }

    async def get_market_sentiment(
        self,
        rates: Optional[Dict[str, float]] = None,
        news: Optional[List[Dict]] = None,
    ) -> Dict[str, any]:
        """
        Get market sentiment analysis
        """
        try:
            effective_rates = rates if rates is not None else await self.get_currency_rates()
            effective_news = news if news is not None else await self.get_forex_factory_news()

            return await self.analyze_market_with_gemini(effective_rates, effective_news)
        except Exception as e:
            print(f"Error getting market sentiment: {e}")
            return {}

    async def stream_live_data(self, callback, interval: int = 10, should_poll=None):
        """
        Stream live forex data at specified interval (seconds)

        Args:
            callback: Async function to call with new data
            interval: Update interval in seconds
        """
        self.running = True
        safe_interval = max(2, int(interval))
        await self.initialize()

        try:
            while self.running:
                if should_poll is not None:
                    try:
                        if not bool(should_poll()):
                            await asyncio.sleep(safe_interval)
                            continue
                    except Exception:
                        await asyncio.sleep(safe_interval)
                        continue

                try:
                    # Fetch once per cycle and reuse for sentiment to avoid duplicate upstream calls.
                    rates = await self.get_currency_rates()
                    news = await self.get_forex_factory_news()
                    sentiment = await self.get_market_sentiment(rates=rates, news=news)

                    # Prepare update package
                    update_data = {
                        "timestamp": datetime.now().isoformat(),
                        "rates": rates,
                        "news": news[:3],  # Top 3 news items
                        "sentiment": sentiment,
                        "type": "live_update"
                    }

                    # Send to callback
                    await callback(update_data)
                except Exception as e:
                    print(f"Live data stream iteration error: {e}")

                adaptive_sleep = safe_interval
                if self._rate_failure_streak > 0:
                    adaptive_sleep = max(
                        adaptive_sleep,
                        int(min(90, 2 ** min(self._rate_failure_streak, 6))),
                    )
                await asyncio.sleep(adaptive_sleep)

        except asyncio.CancelledError:
            print("Live data stream cancelled")
        finally:
            self.running = False
            await self.close()

    def stop_streaming(self):
        """Stop the live data stream"""
        self.running = False


# Global instance
forex_service = ForexDataService()
