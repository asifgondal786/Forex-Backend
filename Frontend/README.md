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
  --dart-define=WS_BASE_URL=wss://api.your-domain.com \
  --dart-define=ALLOW_DEBUG_USER_FALLBACK=false \
  --dart-define=SKIP_AUTH_GATE=false
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
