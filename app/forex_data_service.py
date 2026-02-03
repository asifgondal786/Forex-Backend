"""
Forex Data Service - Fetches real-time data from multiple sources
"""
import asyncio
import aiohttp
from datetime import datetime
from typing import Dict, List, Optional


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

    async def get_market_sentiment(self) -> Dict[str, any]:
        """
        Get market sentiment analysis
        """
        try:
            rates = await self.get_currency_rates()

            return {
                "timestamp": datetime.now().isoformat(),
                "trend": "bullish",
                "major_pairs": rates,
                "volatility": "medium",
                "risk_level": "moderate"
            }
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