flutter build web --pwa-strategy=none --dart-define=API_BASE_URL=http://140.245.33.196:8000 --dart-define=WS_BASE_URL=ws://140.245.33.196:8000 --dart-define=APP_WEB_URL=https://forexcompanion-e5a28.web.app
firebase deploy --only hosting
