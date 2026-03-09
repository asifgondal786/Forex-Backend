# run_with_gemini.ps1
# DEPRECATED: The Gemini API key is no longer passed to the Flutter client.
# The key now lives as a Railway environment variable in the backend.
#
# To run the app locally:
#   flutter run -d chrome
#
# The app will call: https://forex-backend-production-bc44.up.railway.app/api/ai/chat
# Make sure GEMINI_API_KEY is set in your Railway service variables.

Write-Host "Running Flutter app (Gemini key is backend-only now)..." -ForegroundColor Green
flutter run -d chrome
