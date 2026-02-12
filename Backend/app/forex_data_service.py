"""
Forex Data Service - Fetches real-time data from multiple sources
Integrates with Google Generative AI (Gemini) for market analysis and predictions
"""
import asyncio
import aiohttp
from datetime import datetime
from typing import Dict, List, Optional
import os
import google.generativeai as genai
from dotenv import load_dotenv

# Load environment variables
load_dotenv()

# Configure Gemini API
GEMINI_API_KEY = os.getenv("GEMINI_API_KEY")
if GEMINI_API_KEY:
    genai.configure(api_key=GEMINI_API_KEY)


class ForexDataService:
    """Service to fetch real-time forex data from multiple sources"""

    def __init__(self):
        self.session: Optional[aiohttp.ClientSession] = None
        self.running = False

    async def initialize(self):
        """Initialize the HTTP session"""
        if not self.session or self.session.closed:
            self.session = aiohttp.ClientSession()

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
        try:
            # Free API - no key required for basic usage
            url = "https://api.exchangerate-api.com/v4/latest/USD"

            if not self.session:
                await self.initialize()

            async with self.session.get(url, timeout=10) as response:
                if response.status == 200:
                    data = await response.json()
                    rates = data.get("rates", {})
                    return {
                        "EUR/USD": 1 / rates.get("EUR", 1),
                        "GBP/USD": 1 / rates.get("GBP", 1),
                        "USD/JPY": rates.get("JPY"),
                        "USD/CHF": rates.get("CHF"),
                        "AUD/USD": 1 / rates.get("AUD", 1),
                        "USD/CAD": rates.get("CAD"),
                        "NZD/USD": 1 / rates.get("NZD", 1),
                    }
        except Exception as e:
            print(f"Error fetching currency rates: {e}")
            return {}

    async def analyze_market_with_gemini(self, rates: Dict[str, float], news: List[Dict]) -> Dict[str, any]:
        """
        Use Google Generative AI (Gemini) to analyze market conditions from real-time data
        """
        try:
            if not GEMINI_API_KEY:
                return self.get_default_sentiment(rates)
                
            model = genai.GenerativeModel("gemini-1.5-pro")
            
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
            if not GEMINI_API_KEY:
                return {
                    "success": False,
                    "message": "Gemini API key not configured",
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

    async def get_market_sentiment(self) -> Dict[str, any]:
        """
        Get market sentiment analysis
        """
        try:
            rates = await self.get_currency_rates()
            news = await self.get_forex_factory_news()
            
            return await self.analyze_market_with_gemini(rates, news)
        except Exception as e:
            print(f"Error getting market sentiment: {e}")
            return {}

    async def stream_live_data(self, callback, interval: int = 10):
        """
        Stream live forex data at specified interval (seconds)

        Args:
            callback: Async function to call with new data
            interval: Update interval in seconds
        """
        self.running = True
        await self.initialize()

        try:
            while self.running:
                # Fetch all data types
                rates = await self.get_currency_rates()
                news = await self.get_forex_factory_news()
                sentiment = await self.get_market_sentiment()

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

                # Wait for next update
                await asyncio.sleep(interval)

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