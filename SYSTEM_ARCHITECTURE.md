# System Architecture

## High-level structure
- Frontend: Flutter app in `Frontend/`
- Backend: FastAPI app in `Backend/`
- Data and identity integrations:
  - Firebase authentication and optional Firestore-backed state
  - Broker bridge and market data services
  - Notification channel adapters

## Frontend layers (`Frontend/lib`)
- `features/`
  - Embodied agent screen and widgets
  - Auth flow
  - Admin/user dashboard
- `providers/`
  - State orchestration for user, tasks, account connection, agent behavior
- `services/`
  - API client, live WebSocket updates, voice assistant adapters
- `core/`
  - Shared models, theme, background and reusable UI components

## Backend layers (`Backend/app`)
- Routes
  - `users.py`, `accounts_routes.py`, `notifications_routes.py`
  - `advanced_features_routes.py`, `websocket_routes.py`
  - `subscription_routes.py`, `credential_vault_routes.py`
- Services
  - Risk management and autonomy guardrails
  - Security/compliance and audit trails
  - Notification orchestration
  - Broker execution bridge
  - Subscription feature gate logic
  - Encrypted credential vault
- Security middleware
  - Auth verification, rate limiting, request-size controls, CORS policy

## Core runtime flow
1. Client authenticates (Firebase token or explicit dev mode in local environment).
2. Frontend requests user state, guardrails, market context, and account data.
3. User submits command or rule.
4. Backend validates risk, compliance, and subscription access.
5. If allowed, backend executes via broker bridge (or paper mode) and returns explainable result.
6. Notifications and live updates are pushed to connected clients.

## Safety flow for autonomous actions
1. Command/request enters backend.
2. Guardrail checks run:
  - Risk budget and drawdown checks
  - Probation/compliance state
  - Explain-before-execute token validation
3. Broker execution is attempted only when checks pass.
4. Action is logged and surfaced through decision/notification channels.

## Configuration model
- Backend environment controls:
  - Auth behavior, CORS, trusted hosts, request-size limits
  - Credential vault keying
  - Subscription gating switches
- Frontend compile-time flags:
  - API/WS endpoints
  - Debug-only bypass toggles
  - Release auth requirements

