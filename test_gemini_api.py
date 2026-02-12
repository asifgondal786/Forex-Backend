import os
from dotenv import load_dotenv
import google.generativeai as genai

# Load environment variables
load_dotenv()

# Configure the API key
api_key = os.getenv("GEMINI_API_KEY")
if not api_key:
    raise ValueError("GEMINI_API_KEY environment variable is not set")

print(f"API Key found: {api_key}")
print(f"API Key length: {len(api_key)}")

# Verify API key is correct
expected_key = "AIzaSyAFOrej9g18udL_Wv6EfDAT_TyfXWZq8l8"
if api_key == expected_key:
    print("✅ API key is correct!")
else:
    print(f"❌ API key is incorrect. Expected: {expected_key}")

# Configure the generative AI client
genai.configure(api_key=api_key)

# Test the API with a simple query
try:
    # List available models
    models = genai.list_models()
    print("\n✅ Successfully connected to Gemini API!")
    
    # Find a text model
    text_model = None
    for model in models:
        if "generateContent" in model.supported_generation_methods:
            text_model = model.name
            break
    
    if text_model:
        print(f"✅ Found text generation model: {text_model}")
        
        # Test the model
        model = genai.GenerativeModel(text_model)
        response = model.generate_content("Hello, world!")
        
        if response.text:
            print("✅ Model response received!")
            print(f"Response: {response.text}")
    else:
        print("⚠️ No text generation models found")
        
except Exception as e:
    print(f"❌ Error testing Gemini API: {e}")