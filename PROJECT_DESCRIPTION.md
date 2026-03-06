# Forex Companion - Full Project Description

## 1. Project Overview
Forex Companion is an AI-powered forex copilot platform with:
- A Flutter frontend for web/mobile user interaction.
- A FastAPI backend for trading workflows, risk controls, notifications, and real-time streaming.
- Firebase services for identity and persistent app data.

The system is designed around one core idea: enable autonomous or assisted forex workflows while keeping strict control of risk, security, and explainability.

## 2. Product Intent and Operating Model
The product combines three usage modes:
- Manual/assisted operation for user-directed actions.
- Guarded autonomy with configurable risk budgets and probation controls.
- Full autonomy for advanced users with additional safeguards, explicit confirmation, and kill-switch override.

Primary goals:
- Provide a single control plane for forex tasking, analysis, and execution.
- Enforce safety-first automation through guardrails.
- Keep trade decisions transparent via explain-before-execute and decision logs.
- Support scalable growth through subscriptions, feature gating, and operational observability.

## 3. High-Level Architecture
### Frontend
- Stack: Flutter, Provider state management, Firebase Auth integration, WebSocket streaming.
- Main UX: embodied agent interface, chat/command inputs, admin/user dashboard, task workflows.

### Backend
- Stack: Python FastAPI, WebSockets, Firebase Admin SDK, Firestore, optional Redis-backed queueing.
- Responsibilities:
  - Auth and request validation.
  - Task lifecycle orchestration.
  - Market data and intelligence.
  - Autonomous trading guardrails and execution controls.
  - Multi-channel notifications.
  - Monitoring/ops endpoints and alert hooks.

### Data and Identity
- Firebase Auth used for user identity token verification.
- Firestore used for tasks, settings, header data, subscriptions, notifications, and vault records.
- Optional local/dev identity fallback via `x-user-id` under strict environment gating.

## 4. Repository Structure
### Root
- `Frontend/`: Flutter application.
- `Backend/`: FastAPI backend application.
- `README.md`: concise project entry.
- `PROJECT_DESCRIPTION.md`: this full document.
- Multiple implementation/phase/security docs for operational and strategic planning.

### Backend key folders
- `app/`: API routes, services, middleware, config, utilities.
- `tests/`: pytest test suite.
- `docs/`: development, deployment, security, incident response, and business ops docs.
- `scripts/`: security checks, business checks, git hooks install scripts.

### Frontend key folders
- `lib/features/`: screens and feature modules.
- `lib/providers/`: app state orchestration.
- `lib/services/`: API, websocket, Gemini, Firebase services.
- `lib/routes/`: route table and protected navigation.

## 5. Backend Technical Details
### 5.1 Runtime and Core Dependencies
- Python 3.11/3.12 compatible.
- FastAPI + Uvicorn.
- Firebase Admin SDK.
- Pydantic v2.
- aiohttp/httpx for external integrations.
- Optional Redis for queue/registry scaling.
- cryptography (Fernet) for credential vault encryption.

### 5.2 API Composition
Major route groups:
- `/api/users`: current user profile and preferences.
- `/api/tasks`: AI task lifecycle (create/list/get/pause/resume/stop/delete), queue status, market snapshots.
- `/api/advanced`: advanced autonomy, risk, execution intelligence, paper trading, NLP, compliance, feature status.
- `/api/accounts`: broker account connect/disconnect/balance.
- `/api/credentials`: encrypted vault status/list/save/delete.
- `/api/subscription`: subscription and feature-matrix endpoints.
- `/api/notifications`: notification feed, preferences, deep-study, digest, autonomous alerts.
- `/api/monitoring`: metrics, health, readiness, diagnostics, trace context.
- `/api/ops`: runtime status, alerting, readiness checks, Prometheus metrics.
- `/api/ws` and `/api/ws/{task_id}`: authenticated WebSocket streams.
- `/auth/password-reset`, `/auth/email-verification`, `/auth/email-provider-status`: public auth utility endpoints.

Health endpoints:
- `/health` (minimal, fast, deployment healthcheck safe).
- `/healthz`.
- `/api/health`.

### 5.3 Security and Request Controls
Implemented controls include:
- Strict auth middleware for `/api/*` endpoints.
- Firebase bearer token verification.
- Optional dev fallback via `x-user-id` only when explicitly allowed.
- CORS policy with environment-driven allowlists and optional regex.
- Trusted host middleware support.
- Security headers:
  - CSP (or report-only mode).
  - HSTS (production baseline).
  - X-Content-Type-Options, X-Frame-Options, Referrer policy, COOP/CORP.
- Request-size limit middleware (`MAX_REQUEST_BODY_BYTES`).
- API rate limiting and dedicated auth endpoint rate limiting.
- WebSocket auth, connection rate limits, and heartbeat timeout enforcement.
- Unified API response envelope middleware and request ID middleware.

### 5.4 Autonomous Trading and Guardrails
Core autonomous safety mechanisms:
- Configurable risk budgets per user.
- Probation policy gates before live autonomous execution.
- Explain-before-execute flow with one-time execution token binding.
- Trade fingerprint validation to prevent drift between explain and execute steps.
- Kill switch for immediate autonomy halt.
- Compliance/legal acknowledgment checks for live pathways.
- Optional broker fail-safe requirements.

Execution modes:
- Paper trading workflows for safer onboarding and evaluation.
- Live execution flow gated by subscription/compliance/guardrails.

### 5.5 Task Processing and Queueing
Task flows:
- Task records stored in Firestore.
- Asynchronous task processing supports:
  - in-memory queue backend.
  - Redis-backed queue backend for scaling.
- Queue handlers process market analysis, auto-trade, and forecast jobs.
- Queue stats and health exposed through ops/monitoring endpoints.

### 5.6 Market Data and Intelligence
Market pipeline includes:
- Exchange rates from exchangerate-api (with fallback values and retry backoff).
- Cached forex news and sentiment windows.
- Pair-specific forecast generation with horizon support (`intraday`, `1d`, `1w`).
- Gemini-assisted sentiment/analysis when configured.
- Deep-study intelligence from multiple sources (Forex Factory, Google News RSS style feeds, Reddit RSS, chart context).

### 5.7 Notifications and Communications
Notification engine capabilities:
- Template-based message generation.
- Priority/category-aware dispatch.
- User-level channel preferences and quiet-hour controls.
- Autonomous-mode suppression/escalation rules based on deep-study confidence and risk.
- Delivery channels:
  - in-app
  - email
  - webhook
  - Telegram
  - Discord
  - X (webhook-based)
  - WhatsApp (webhook-based)
  - SMS (webhook-based)
- Digest generation (`daily/weekly/hourly` style modes).

Email delivery providers:
- Brevo (preferred path).
- Mailjet fallback.
- SMTP fallback.

### 5.8 Credential Vault and Subscription Gating
Credential vault:
- Stores broker credentials encrypted at rest using Fernet.
- Supports configured key, derived passphrase key, and debug-only ephemeral mode.
- Returns masked metadata for UI and decrypts only at execution/connect time.

Subscription service:
- Plan model: `free`, `premium`, `enterprise`.
- Feature gating map for premium capabilities (e.g., live broker execution, full autonomy, API key management).
- Optional paywall toggles and dev bypass settings.

### 5.9 Observability and Ops
Monitoring features:
- Request metrics and error tracking middleware.
- Trace context support.
- Dependency health checks.
- `/api/ops/metrics` Prometheus-compatible output.
- Alert generation from queue depth, websocket staleness, forex failure streak, retry backoff.
- Optional webhook alerts for trigger/resolution events (generic/Slack/Discord style handling).

## 6. Frontend Technical Details
### 6.1 Runtime and Libraries
- Flutter (Material app).
- Provider for state.
- Firebase Core/Auth/Firestore/Storage packages.
- HTTP and WebSocket client libraries.
- Optional Gemini client integration via compile-time key.

### 6.2 App Entry and Configuration Guards
Startup safeguards include:
- Release-time assertion requiring `API_BASE_URL` and `APP_WEB_URL`.
- HTTPS enforcement for runtime URLs in non-debug contexts.
- Optional debug user fallback controls with compile-time flags.

Key compile-time flags:
- `API_BASE_URL`
- `WS_BASE_URL`
- `APP_WEB_URL`
- `ALLOW_DEBUG_USER_FALLBACK`
- `SKIP_AUTH_GATE`
- `DEV_USER_ID`
- `REQUIRE_AUTH_IN_RELEASE`
- `GEMINI_API_KEY`

### 6.3 Navigation and Core Screens
Routes include:
- Auth entry/login/signup/verification/reset.
- Main dashboard (`EmbodiedAgentScreen`).
- Task creation/history.
- AI chat.
- Settings.
- User/Admin dashboard profile view.

Protected route behavior:
- If Firebase is unavailable or user is unauthenticated, app redirects to login flow.

### 6.4 State Management
Primary providers:
- `TaskProvider`: task CRUD lifecycle and state syncing.
- `UserProvider`: profile fetch/update and auth-aware user state.
- `HeaderProvider`: top bar/header data.
- `ThemeProvider`: theme controls.
- `AccountConnectionProvider`: broker account connection state.
- `AgentOrchestratorProvider`: autonomous agent behavior, command parsing, guardrails, voice interactions, decision log.

### 6.5 Embodied Agent Experience
The embodied agent screen includes:
- Real-time agent state visualization (monitoring/analyzing/trading/paused).
- Autonomy mode controls (manual/assisted/semi-auto/full-auto).
- Guardrail adjustments and apply action.
- Kill switch floating action.
- Conversation stream and decision log.
- Embedded market intelligence widgets (forex feed, sentiment/news, account status).

### 6.6 Frontend-Backend Integration
`ApiService` supports:
- Auth headers with Firebase ID token.
- Dev-user fallback headers in debug contexts.
- Unified handling of backend response envelope.
- Endpoint methods for users, tasks, accounts, notifications, forex data, autonomous controls, and feature status.

`LiveUpdatesService` supports:
- Global authenticated WebSocket connection.
- Rate/notification stream parsing.
- heartbeat/ping-pong compatibility.
- reconnect scheduling.

## 7. End-to-End Operational Flows
### 7.1 Authentication and User Bootstrap
1. User signs in through Firebase-auth-aware UI.
2. Frontend includes Firebase token in API/WebSocket requests.
3. Backend verifies token and resolves scoped user identity.
4. User profile/header/settings data is loaded from backend services.

### 7.2 Task Workflow
1. User creates task in frontend.
2. Backend persists task and schedules execution (queue or background fallback).
3. Progress and updates stream through WebSocket channels.
4. Task state can be paused/resumed/stopped/deleted via API.

### 7.3 Autonomous Trade Workflow
1. Client submits command or direct autonomous action request.
2. Backend evaluates guardrails, compliance, subscription, and deep-study intelligence.
3. Backend issues explain-before-execute data and execution token.
4. Execution request consumes token and validates unchanged trade fingerprint.
5. Trade executes (paper or live bridge), logs updates, and emits notifications.

### 7.4 Notification Workflow
1. Event generated (trade execution, risk warning, stage update, etc.).
2. User channel preferences are loaded/merged.
3. Deep-study confidence and autonomous suppression policy applied.
4. Notifications are delivered across enabled channels.
5. In-app records are persisted for timeline/history and digest generation.

## 8. Environment Configuration Summary
### 8.1 Backend `.env` groups
- Runtime/profile: `ENVIRONMENT`, `DEBUG`, `CONFIG_VALIDATION_FAIL_FAST`.
- Frontend URL linking and redirect safety.
- CORS and host security controls.
- Auth and API rate-limiting controls.
- Firebase project and credential settings.
- Email provider credentials.
- Feature toggles for stream/queue/redis/alerts.
- Subscription and credential vault settings.
- WebSocket heartbeat and stream tuning.

### 8.2 Frontend env/defines
- `.env.example` documents app URL, API URL, and Firebase web config placeholders.
- Release deployment relies on `--dart-define` values, enforced by build guard.

## 9. Development Workflow
### 9.1 Backend local setup
1. Create and activate venv.
2. `pip install -r requirements.txt`.
3. Configure `.env` from `.env.example`.
4. Validate env: `python -m app.config.validate_env --json`.
5. Run server: `uvicorn app.main:app --reload --port 8080` or `python run.py`.

Recommended scripts:
- `scripts/install-git-hooks.ps1`
- `scripts/security-healthcheck.ps1`
- `scripts/business-ops-check.ps1`

### 9.2 Frontend local setup
1. `flutter pub get`
2. `flutter run`
3. For release build, define secure runtime URLs and disable debug bypass flags.
4. Optional helper script: `build_web_release.ps1`.

## 10. Deployment Architecture
### 10.1 Backend deployment (Railway)
- Root directory: `Backend`.
- Build: Nixpacks (`nixpacks.toml`).
- Start command: Uvicorn with proxy headers.
- Healthcheck path: `/health`.

### 10.2 Frontend deployment (Firebase Hosting)
- Build output: `build/web`.
- SPA rewrite to `index.html`.
- Security/cache headers configured in `Frontend/firebase.json`.
- Default production endpoints point to:
  - Railway backend URL.
  - Firebase hosting app URL.

## 11. Testing and Automation
### 11.1 Backend tests
Pytest suite covers:
- API behaviors.
- env/config validation.
- audit middleware.
- websocket and queue behavior.
- subscription logic.
- security CSP/CORS regression checks.
- observability and ops routes.

### 11.2 CI/Automation
Backend workflows include:
- Security scan on push/PR.
- Weekly security operations run and artifact upload.
- Monthly business operations check and artifact upload.

## 12. Documentation Landscape
Documentation is split into:
- Runtime/engineering docs (`DEVELOPMENT.md`, `DEPLOYMENT.md`, `TROUBLESHOOTING.md`, `SECRETS_MANAGEMENT.md`).
- Security/incident docs (`SECURITY_CHECKLIST.md`, `INCIDENT_RESPONSE.md`, audit templates/metrics trackers).
- Phase and strategic growth docs in `Backend/docs` and project root.

## 13. Current Maturity Snapshot
Current implementation status:
- Strong end-to-end prototype with production-oriented controls already implemented.
- Security posture includes auth enforcement, rate limits, secure headers, and vault encryption.
- Autonomy infrastructure exists with practical guardrails and explain-before-execute controls.
- Operational readiness tooling (health, metrics, alerts, scheduled checks) is present.

Constraints to note:
- Some domain data sources are simulated/fallback-based and should be hardened for strict production-grade market execution.
- Several stores are Firestore-centric with in-memory fallbacks in specific modules.
- Production rollout should keep staged progression: paper mode -> restricted beta -> guarded live mode.

## 14. Recommended Production Baseline
- `DEBUG=false`
- `ALLOW_DEV_USER_ID=false`
- strict `CORS_ORIGINS` and `ALLOWED_HOSTS`
- `ENABLE_HSTS=true` and `ENABLE_CSP=true`
- configured `CREDENTIAL_VAULT_MASTER_KEY`
- `REQUIRE_FIREBASE=true` with valid service account credentials
- release frontend with secure `https://` / `wss://` endpoints
- debug bypass flags disabled in release builds

## 15. Summary
Forex Companion is a full-stack AI forex copilot platform combining:
- rich embodied frontend UX,
- modular backend autonomy/risk/compliance services,
- secure authentication and credential handling,
- real-time updates and alerting,
- and deployment/ops tooling for staged production rollout.

It is architected for controlled autonomy rather than raw automation, prioritizing guardrails, transparency, and operational governance.
