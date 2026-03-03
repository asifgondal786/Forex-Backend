import os

from dotenv import load_dotenv
import google.generativeai as genai

# Load environment variables from local .env files if present.
load_dotenv()

api_key = (os.getenv("GEMINI_API_KEY") or "").strip()
if not api_key:
    raise ValueError("GEMINI_API_KEY environment variable is not set")

redacted = f"{api_key[:4]}***" if len(api_key) >= 4 else "***"
print(f"API key found: {redacted}")
print(f"API key length: {len(api_key)}")

genai.configure(api_key=api_key)

try:
    models = genai.list_models()
    print("Connected to Gemini API.")

    text_model = None
    for model in models:
        if "generateContent" in model.supported_generation_methods:
            text_model = model.name
            break

    if text_model:
        print(f"Found text generation model: {text_model}")
        active_model = genai.GenerativeModel(text_model)
        response = active_model.generate_content("Hello, world!")
        if response.text:
            print("Model response received.")
            print(f"Response: {response.text}")
    else:
        print("No text generation models found.")
except Exception as exc:
    print(f"Error testing Gemini API: {exc}")
