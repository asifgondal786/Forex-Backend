# Forex Companion

Forex Companion is an AI-powered forex copilot with an embodied bot interface, autonomous trading guardrails, and secure account management.

## What this project includes
- `Frontend/`: Flutter app (web/mobile) with embodied agent UI, chat, voice hooks, market widgets, and user/admin dashboard.
- `Backend/`: FastAPI services for market data, autonomous decision orchestration, risk controls, notifications, account bridge, and security.
- `public/` and Firebase config files: deployment/static hosting assets.

## Core capabilities
- Embodied autonomous agent UI for market monitoring and interaction.
- Rule-based and autonomy-based trading directives.
- Risk and compliance controls (guardrails, kill switch, explain-before-execute).
- Broker bridge integration flow (Forex.com account connection).
- Multi-channel notification support (in-app, email, SMS, WhatsApp adapters).
- Subscription-ready backend feature gates and encrypted credential vault.

## Documentation
- Project description: `PROJECT_DESCRIPTION.md`
- System architecture: `SYSTEM_ARCHITECTURE.md`
- Security overview: `SECURITY_OVERVIEW.md`
- Backend run/setup details: `Backend/READ.md`
- Frontend run/setup details: `Frontend/README.md`

## Current maturity
- Strong prototype with production-oriented building blocks.
- Suitable for staged rollout:
  1. Demo and paper-trading first.
  2. Guardrail-governed live trading after compliance, key management, and monitoring hardening.

