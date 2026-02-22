# Forex Companion: Project Weave Deep Study

## 1) Core System Shape
- `Frontend/` is a Flutter client that runs the embodied agent UX, voice/chat control plane, risk controls, and market intelligence widgets.
- `Backend/` is a FastAPI service that handles market data, AI/autonomy workflows, execution/risk routes, websocket live updates, notification orchestration, and security middleware.
- The app uses a single orchestration UX pattern: user instructions (voice/text) feed one orchestrator that routes to autonomy controls, briefings, execution calls, and notifications.

## 2) Frontend Weave
- `lib/providers/agent_orchestrator_provider.dart`
  - Main autonomous brain on client side.
  - Handles command parsing, autonomy mode switching, periodic briefings, kill-switch handling, explainability timeline, and voice lifecycle.
- `lib/services/api_service.dart`
  - Unified HTTP client for guardrails, execution, market feeds, notifications, and deep-study endpoints.
- `lib/features/embodied_agent/`
  - Embodied dashboard shell with avatar stage, control panels, conversation board, and merged market widgets.
- `lib/services/voice_assistant_service_web.dart`
  - Browser speech synthesis + recognition implementation (Web Speech APIs).

## 3) Backend Weave
- `app/main.py`
  - App composition: middleware, security controls, CORS, rate limiting, router registration.
- `app/security.py`
  - Auth resolution for Firebase tokens and controlled dev-user fallback.
- `app/websocket_routes.py`
  - Real-time update and forex streaming channels.
- `app/services/market_intelligence_service.py`
  - Multi-source deep-study synthesis (charts + Forex Factory + Google News/RSS sources), with consensus score, confidence band, and recommendation.
- `app/services/enhanced_notification_service.py`
  - Multi-channel notification engine (in-app, email, sms, whatsapp, etc.), templates, user preference state, deep-study-backed alerts, cadence control.
- `app/notifications_routes.py`
  - Notification APIs, deep-study endpoint, autonomous-study alerts, and stage-awareness endpoint.

## 4) Runtime Data Flow
- User command -> `AgentOrchestratorProvider` -> command intent path.
- Market refresh loop -> rates/news/sentiment + deep-study -> spoken/text briefing + decision log.
- Autonomous cycle -> explain-before-execute -> guarded trade execution -> stage-aware notifications.
- Stage transitions (`analyzing`, `trading`, `executed`, `risk_lock`, `paused`, `briefing`) -> `/api/notifications/autonomous-awareness` -> user channels.

## 5) Security Weave (Current)
- Request auth guard on `/api/*` endpoints.
- Rate limiting + request body size limits.
- Security headers + configurable CSP/HSTS.
- WebSocket auth checks and connection rate limiting.
- Credential vault and account modules are isolated into dedicated routes/services.

## 6) Practical Next Priorities
- Add broker execution idempotency keys and replay protection.
- Add signed, immutable audit trail for every autonomous stage + trade.
- Add per-user policy packs (starter/pro/enterprise) for guardrails and alert cadences.
- Add supervised paper-trading graduation gate before any live execution escalation.
