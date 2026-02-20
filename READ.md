# Forex Companion Backend

FastAPI backend for the Forex Companion app. Provides task APIs, WebSocket updates, engagement routes, and Firebase Admin integration.

## Quick Start (Local)

1. Create and activate a virtual environment:
```bash
python -m venv .venv
.venv\Scripts\activate  # Windows
# source .venv/bin/activate  # Linux/Mac
```

2. Install dependencies:
```bash
pip install -r requirements.txt
```

3. Configure environment variables (see `.env.example`).

4. Run the server:
```bash
uvicorn app.main:app --reload --port 8080
# or: python run.py
# Windows dev helper (sets CORS + dev-user flags):
powershell -ExecutionPolicy Bypass -File .\run-dev.ps1
```

Notes for local Flutter web:
- In `DEBUG=true`, backend now allows localhost/127.0.0.1 on any port by default.
- Dev `x-user-id` auth fallback is enabled by default in debug mode (can be overridden with `ALLOW_DEV_USER_ID=false`).

5. Verify:
   - API docs: `http://localhost:8080/docs`
   - Health: `http://localhost:8080/health`

## Railway Deploy (Nixpacks)

1. Set **Root Directory** to `Backend`.
2. Railway will use `nixpacks.toml` and `railway.json`.
3. Add required environment variables (below).
4. Deploy.

### Required Environment Variables

Minimum (Firebase Admin):
```
FIREBASE_SERVICE_ACCOUNT_JSON=<one-line-json>
FIREBASE_PROJECT_ID=forexcompanion-e5a28
REQUIRE_FIREBASE=true
```

Security/CORS:
```
ALLOW_DEV_USER_ID=false
CORS_ORIGINS=https://your-frontend-domain
ALLOWED_HOSTS=api.your-domain.com
ENABLE_HSTS=true
ENABLE_CSP=true
MAX_REQUEST_BODY_BYTES=1048576
```

Optional:
```
FOREX_STREAM_ENABLED=true
RATE_LIMIT_ENABLED=true
RATE_LIMIT_MAX=120
RATE_LIMIT_WINDOW_SECONDS=60
DEBUG=false
ENABLE_CSP=false
ENABLE_ENGAGEMENT_LOGGING=true
```

Credential vault + subscription rollout:
```
SUBSCRIPTION_PAYWALL_ENABLED=false
SUBSCRIPTION_PREMIUM_PRICE_USD=10
SUBSCRIPTION_ALLOW_DEV_BYPASS=true
SUBSCRIPTION_ALLOW_SELF_SERVICE_MANAGEMENT=true
CREDENTIAL_VAULT_MASTER_KEY=<fernet-key>
```

Dev auth safety (recommended):
```
# Only for local development:
ALLOW_DEV_USER_ID=true
DEV_USER_LOCALHOST_ONLY=true
DEV_AUTH_SHARED_SECRET=<strong-local-secret>
```

## WebSocket & API Notes

- WebSocket:
  - Global stream: `/api/ws`
  - Task stream: `/api/ws/{task_id}`
- Tasks API:
  - `POST /api/tasks/create`
  - `GET /api/tasks/`
  - `GET /api/tasks/{task_id}`
  - `POST /api/tasks/{task_id}/pause|resume|stop`
- Subscription API:
  - `GET /api/subscription/me`
  - `GET /api/subscription/me/features`
  - `POST /api/subscription/me/plan`
- Credential Vault API:
  - `GET /api/credentials/status`
  - `GET /api/credentials/forex`
  - `POST /api/credentials/forex`
  - `DELETE /api/credentials/forex/{credential_id}`
