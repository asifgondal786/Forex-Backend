import httpx
from datetime import datetime, timedelta
import asyncio
import random

# --- Configuration ---
# It's better to use a dedicated Forex data provider API.
# This is a placeholder using a free but limited API.
# Replace with a real-time, high-frequency data source for production.
<<<<<<< HEAD
EXCHANGE_RATE_API_URL = "https://v6.exchangerate-api.com/v6/"
# IMPORTANT: Replace with your own Alpha Vantage API key
EXCHANGE_RATE_API_KEY = "06efe0dc7c3325d213613a1d"
=======
ALPHA_VANTAGE_API_URL = "https://www.alphavantage.co/query"
# IMPORTANT: Replace with your own Alpha Vantage API key
ALPHA_VANTAGE_API_KEY = "YOUR_ALPHA_VANTAGE_API_KEY"
>>>>>>> 6ea3e47c (AI task button files)

class ForexDataService:
    """
    Service to fetch live and historical Forex data.
    """
<<<<<<< HEAD
    def __init__(self, api_key: str = EXCHANGE_RATE_API_KEY):
=======
    def __init__(self, api_key: str = ALPHA_VANTAGE_API_KEY):
        if api_key == "YOUR_ALPHA_VANTAGE_API_KEY":
            print("⚠️ Warning: Using a placeholder API key for ForexDataService. Please replace it.")
>>>>>>> 6ea3e47c (AI task button files)
        self._api_key = api_key
        self._client = httpx.AsyncClient()

    async def get_realtime_price(self, currency_pair: str):
        """
        Fetches the real-time price for a given currency pair.
        
        Example currency_pair: "EUR/USD"
        """
        from_currency, to_currency = currency_pair.split('/')
<<<<<<< HEAD
        url = f"{EXCHANGE_RATE_API_URL}{self._api_key}/latest/{from_currency}"
        
        try:
            response = await self._client.get(url)
            response.raise_for_status()
            data = response.json()
            
            if data.get("result") == "success":
                rate = data["conversion_rates"].get(to_currency)
                if rate:
                    # Simulate spread for bid/ask
                    price = float(rate)
                    spread = price * 0.0005  # 0.05% spread
                    return {
                        "price": price,
                        "timestamp": datetime.fromtimestamp(data["time_last_update_unix"]),
                        "bid": price - spread,
                        "ask": price + spread,
                    }
                else:
                    print(f"Currency {to_currency} not found in conversion rates.")
                    return self._generate_mock_price(currency_pair)
            else:
                print(f"ExchangeRate-API Error: {data.get('error-type')}. Falling back to mock data.")
=======
        params = {
            "function": "CURRENCY_EXCHANGE_RATE",
            "from_currency": from_currency,
            "to_currency": to_currency,
            "apikey": self._api_key,
        }
        try:
            response = await self._client.get(ALPHA_VANTAGE_API_URL, params=params)
            response.raise_for_status()
            data = response.json()
            
            if "Realtime Currency Exchange Rate" in data:
                rate_data = data["Realtime Currency Exchange Rate"]
                return {
                    "price": float(rate_data["5. Exchange Rate"]),
                    "timestamp": datetime.now(),
                    "bid": float(rate_data["8. Bid Price"]),
                    "ask": float(rate_data["9. Ask Price"]),
                }
            elif "Error Message" in data:
                # API limitations might be hit, fallback to mock data
                print(f"Alpha Vantage API Error: {data['Error Message']}. Falling back to mock data.")
                return self._generate_mock_price(currency_pair)
            else:
                # Handle cases where the API call limit is reached.
                print(f"Unexpected response from Alpha Vantage. Falling back to mock data.")
>>>>>>> 6ea3e47c (AI task button files)
                return self._generate_mock_price(currency_pair)

        except httpx.HTTPStatusError as e:
            print(f"HTTP error fetching real-time price for {currency_pair}: {e}")
            return self._generate_mock_price(currency_pair)
        except Exception as e:
            print(f"An error occurred fetching real-time price: {e}")
            return self._generate_mock_price(currency_pair)

    async def get_historical_data(self, currency_pair: str, timeframe: str = "60min", output_size: str = "compact"):
        """
        Fetches historical data for a currency pair.
<<<<<<< HEAD
        NOTE: Historical data is not available on the free plan of exchangerate-api.com.
        """
        print("⚠️ Warning: Historical data is not available on the free plan of exchangerate-api.com.")
        return None
=======
        
        timeframe: '1min', '5min', '15min', '30min', '60min', 'daily', 'weekly', 'monthly'
        output_size: 'compact' (last 100) or 'full'
        """
        function_map = {
            "1min": "FX_INTRADAY", "5min": "FX_INTRADAY", "15min": "FX_INTRADAY", 
            "30min": "FX_INTRADAY", "60min": "FX_INTRADAY",
            "daily": "FX_DAILY", "weekly": "FX_WEEKLY", "monthly": "FX_MONTHLY"
        }
        
        from_symbol, to_symbol = currency_pair.split('/')
        
        params = {
            "function": function_map.get(timeframe, "FX_DAILY"),
            "from_symbol": from_symbol,
            "to_symbol": to_symbol,
            "apikey": self._api_key,
            "outputsize": output_size,
        }
        
        if "INTRADAY" in params["function"]:
            params["interval"] = timeframe
        
        try:
            response = await self._client.get(ALPHA_VANTAGE_API_URL, params=params)
            response.raise_for_status()
            data = response.json()
            
            # Find the time series key (it varies by function)
            time_series_key = next((key for key in data if 'Time Series' in key), None)

            if time_series_key:
                return data[time_series_key]
            else:
                print(f"Could not find time series data in response for {currency_pair}. Response: {data}")
                return None
        except Exception as e:
            print(f"Error fetching historical data for {currency_pair}: {e}")
            return None
>>>>>>> 6ea3e47c (AI task button files)

    def _generate_mock_price(self, currency_pair: str):
        """

        Generates a mock price for a given currency pair.
        This is a fallback for when the API fails.
        """
        # Base prices for common pairs
        base_prices = {
            "EUR/USD": 1.0850,
            "GBP/USD": 1.2700,
            "USD/JPY": 157.0,
            "AUD/USD": 0.6650,
        }
        base = base_prices.get(currency_pair, 1.0)
        
        # Simulate some random fluctuation
        price = base + random.uniform(-0.005, 0.005)
        spread = random.uniform(0.0001, 0.0005)
        
        return {
            "price": round(price, 4),
            "timestamp": datetime.now(),
            "bid": round(price - spread / 2, 4),
            "ask": round(price + spread / 2, 4),
            "mock": True,
        }

async def main():
    """ Main function for testing the service. """
    service = ForexDataService()
    
    # --- Test Real-time Price ---
    print("--- Fetching Real-time Price ---")
    eur_usd_price = await service.get_realtime_price("EUR/USD")
    if eur_usd_price:
        print(f"EUR/USD Price: {eur_usd_price['price']} (Bid: {eur_usd_price['bid']}, Ask: {eur_usd_price['ask']})")

<<<<<<< HEAD
    # --- Test Historical Data (No longer supported on free plan) ---
    print("\n--- Historical Data Fetching (Not Supported on Free Plan) ---")
    historical_data = await service.get_historical_data("GBP/USD", timeframe="60min")
    if historical_data:
        print("Historical data found (unexpected on free plan):")
        latest_points = list(historical_data.items())[:2]
        for timestamp, values in latest_points:
            print(f"Timestamp: {timestamp}, Open: {values['1. open']}, Close: {values['4. close']}")
    else:
        print("As expected, historical data not available on the free plan.")
=======
    # --- Test Historical Data ---
    print("\n--- Fetching Historical Data (60min) ---")
    historical_data = await service.get_historical_data("GBP/USD", timeframe="60min")
    if historical_data:
        # Print the most recent 2 data points
        latest_points = list(historical_data.items())[:2]
        for timestamp, values in latest_points:
            print(f"Timestamp: {timestamp}, Open: {values['1. open']}, Close: {values['4. close']}")
>>>>>>> 6ea3e47c (AI task button files)
            
if __name__ == "__main__":
    asyncio.run(main())
