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
```

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

## WebSocket & API Notes

- WebSocket:
  - Global stream: `/api/ws`
  - Task stream: `/api/ws/{task_id}`
- Tasks API:
  - `POST /api/tasks/create`
  - `GET /api/tasks/`
  - `GET /api/tasks/{task_id}`
  - `POST /api/tasks/{task_id}/pause|resume|stop`

