import os, sys
from app.ai.gemini_client import GeminiClient

print("GEMINI_API_KEY set:", bool(os.getenv("GEMINI_API_KEY")))
print("Key preview:", os.getenv("GEMINI_API_KEY", "")[:8] + "...")

c = GeminiClient()
print("available:", c.available)

if c.available:
    result = c.generate_text(
        model_name="gemini-2.0-flash",
        prompt="Return only this JSON: {\"status\": \"ok\", \"message\": \"Gemini working\"}"
    )
    print("result:", result)
else:
    print("ERROR: Gemini client not available - check API key")