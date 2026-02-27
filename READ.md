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

Queue + WebSocket tuning:
```
TASK_QUEUE_ENABLED=true
TASK_QUEUE_BACKEND=memory
TASK_QUEUE_WORKERS=2
TASK_QUEUE_MAX_SIZE=200
TASK_QUEUE_REDIS_KEY=forex:task_queue
TASK_QUEUE_REDIS_BLOCK_SECONDS=1
FOREX_STREAM_INTERVAL=10
FOREX_RATES_MIN_FETCH_INTERVAL_SECONDS=3
FOREX_NEWS_CACHE_TTL_SECONDS=30
FOREX_SENTIMENT_CACHE_TTL_SECONDS=15
FOREX_FORECAST_CACHE_TTL_SECONDS=20
WS_HEARTBEAT_INTERVAL_SECONDS=25
WS_HEARTBEAT_TIMEOUT_SECONDS=60
```
Redis scaling (optional):
```
REDIS_ENABLED=true
REDIS_URL=redis://localhost:6379/0
REDIS_CONNECT_TIMEOUT_SECONDS=2
REDIS_SOCKET_TIMEOUT_SECONDS=2
REDIS_RETRY_SECONDS=5
WS_REDIS_REGISTRY_KEY=forex:ws:registry
```
Ops alerts/metrics thresholds:
```
OPS_ALERT_HOOKS_ENABLED=true
OPS_ALERT_QUEUE_DEPTH_WARN=80
OPS_ALERT_QUEUE_DEPTH_CRIT=150
OPS_ALERT_QUEUE_FAILED_WARN=1
OPS_ALERT_WS_STALE_SECONDS=120
OPS_ALERT_WS_STALE_COUNT_WARN=1
OPS_ALERT_FOREX_FAILURE_STREAK_WARN=3
OPS_ALERT_FOREX_RETRY_WARN_SECONDS=20
OPS_ALERT_WEBHOOK_URL=
OPS_ALERT_WEBHOOK_PROVIDER=auto
OPS_ALERT_WEBHOOK_MIN_SEVERITY=warning
OPS_ALERT_WEBHOOK_TIMEOUT_SECONDS=5
```
Recommended baseline:
- Keep `WS_HEARTBEAT_TIMEOUT_SECONDS` at least 2x `WS_HEARTBEAT_INTERVAL_SECONDS`.
- Start with `TASK_QUEUE_WORKERS=2`; increase only after measuring CPU saturation and job latency.
- Use `TASK_QUEUE_MAX_SIZE` as backpressure control to avoid memory spikes under burst traffic.
- Keep sentiment/news TTL short (15-30s) so WebSocket updates remain responsive while reducing upstream API and AI churn.
- Use `TASK_QUEUE_BACKEND=redis` only after setting a healthy `REDIS_URL`; otherwise the queue falls back to memory mode automatically.

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
