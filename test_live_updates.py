"""
Test script to verify WebSocket connections and live updates.
Run this after starting the server to test functionality.
"""
import asyncio
import websockets
import json
import aiohttp


async def test_websocket_connection():
    """Test WebSocket connection and receive updates."""
    uri = "ws://localhost:8080/api/ws/test_task_123"

    print("🔌 Connecting to WebSocket...")
    print(f"📡 URI: {uri}")
    print("-" * 60)

    try:
        async with websockets.connect(uri) as websocket:
            print("✅ Connected successfully!")
            print("-" * 60)
            print("📥 Listening for updates for 30 seconds...\n")

            await websocket.send("Hello from test client!")

            timeout = 30
            end_time = asyncio.get_event_loop().time() + timeout

            while asyncio.get_event_loop().time() < end_time:
                try:
                    message = await asyncio.wait_for(websocket.recv(), timeout=1.0)
                    data = json.loads(message)
                    print(f"📨 Update received at {data.get('timestamp')}:")
                    print(f"   Type: {data.get('type', 'N/A')}")
                    print(f"   Message: {data.get('message', 'N/A')}")

                    if 'data' in data and data['data'] and 'rates' in data['data']:
                        print(f"   EUR/USD Rate: {data['data']['rates'].get('EUR/USD', 'N/A')}")

                    print("-" * 20)

                except asyncio.TimeoutError:
                    continue
                except json.JSONDecodeError:
                    print(f"Raw message: {message}")

            print(f"\n✅ Test completed after {timeout} seconds.")

    except websockets.exceptions.WebSocketException as e:
        print(f"❌ WebSocket error: {e}")
        print("\n💡 Make sure the server is running on localhost:8080")
    except Exception as e:
        print(f"❌ Unexpected error: {e}")


async def test_http_endpoints():
    """Test HTTP endpoints."""
    base_url = "http://localhost:8080"
    print("\n" + "=" * 60)
    print("🧪 Testing HTTP Endpoints")
    print("=" * 60)

    async with aiohttp.ClientSession() as session:
        endpoints = {
            "Root": "/",
            "Health": "/health",
            "Forex Rates": "/api/forex/rates",
            "Connections": "/api/updates/connections"
        }
        for name, endpoint in endpoints.items():
            try:
                async with session.get(f"{base_url}{endpoint}") as response:
                    print(f"- Testing {name} ({endpoint}): Status {response.status}")
                    assert response.status == 200
            except Exception as e:
                print(f"  ❌ FAILED: {e}")

    print("\n✅ HTTP tests completed.")
    print("=" * 60)


async def main():
    """Run all tests."""
    print("\n" + "=" * 60)
    print("🧪 FOREX COMPANION - LIVE UPDATES TEST SUITE")
    print("=" * 60)

    try:
        await test_http_endpoints()
    except Exception as e:
        print(f"\n❌ HTTP tests failed: {e}. Make sure the server is running!")
        return

    await test_websocket_connection()

    print("\n" + "=" * 60)
    print("🎉 All tests completed!")
    print("=" * 60)


if __name__ == "__main__":
    try:
        asyncio.run(main())
    except KeyboardInterrupt:
        print("\n\n⏹️  Tests interrupted by user.")