# tajir_frontend

Forex Companion Flutter client.

## Getting Started

### Run the app (local)
```bash
flutter pub get
flutter run
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
