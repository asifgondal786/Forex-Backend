# tajir_frontend

Forex Companion Flutter client.

## Getting Started

### Run the app (local)
```bash
flutter pub get
flutter run
```

## Security Notes

For production builds, configure secure API endpoints and disable debug auth fallbacks:

```bash
flutter build web --release \
  --dart-define=API_BASE_URL=https://api.your-domain.com \
  --dart-define=APP_WEB_URL=https://app.your-domain.com \
  --dart-define=WS_BASE_URL=wss://api.your-domain.com \
  --dart-define=ALLOW_DEBUG_USER_FALLBACK=false \
  --dart-define=SKIP_AUTH_GATE=false
```

Release web builds now fail fast if `API_BASE_URL` or `APP_WEB_URL` is missing.

Project-specific PowerShell helper:

```powershell
.\build_web_release.ps1
```

This defaults to the currently documented production endpoints:

```text
API_BASE_URL=https://forex-backend-production-bc44.up.railway.app
APP_WEB_URL=https://forexcompanion-e5a28.web.app
WS_BASE_URL=wss://forex-backend-production-bc44.up.railway.app
```

Override any value when needed:

```powershell
.\build_web_release.ps1 `
  -ApiBaseUrl "https://api.example.com" `
  -AppWebUrl "https://app.example.com" `
  -WsBaseUrl "wss://api.example.com"
```

Development-only convenience flags (do not use in production):

```bash
flutter run -d chrome \
  --dart-define=DEV_USER_ID=dev_user_001 \
  --dart-define=ALLOW_DEBUG_USER_FALLBACK=true \
  --dart-define=SKIP_AUTH_GATE=true
```

### Enable Gemini AI features
Gemini is configured via a compile-time environment variable.

For local dev:
```bash
flutter run --dart-define=GEMINI_API_KEY=YOUR_KEY
```

Windows PowerShell helper:
```powershell
.\run_with_gemini.ps1 -ApiKey 'YOUR_KEY'
# or:
$env:GEMINI_API_KEY = 'YOUR_KEY'
.\run_with_gemini.ps1
```

For web:
```bash
flutter run -d chrome --dart-define=GEMINI_API_KEY=YOUR_KEY
```

If `GEMINI_API_KEY` is not set, AI features are disabled and the app falls back to placeholders.
