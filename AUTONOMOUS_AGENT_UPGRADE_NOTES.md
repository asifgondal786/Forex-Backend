# Autonomous Agent Upgrade Notes

## Implemented in this pass

## 1) Stage-Awareness Notification Wiring
- Frontend now emits autonomous stage updates to backend endpoint:
  - `POST /api/notifications/autonomous-awareness`
- Emitted stages include:
  - `analyzing`
  - `trading`
  - `executed`
  - `risk_lock`
  - `paused`
  - `briefing`
- Trigger points wired from orchestrator:
  - autonomous cycle start and completion
  - guardrail block conditions
  - kill-switch activation
  - autonomy mode changes
  - periodic/welcome market briefings

## 2) Deep-Study-Backed Briefings
- Frontend briefings now also call:
  - `GET /api/notifications/deep-study`
- Briefing content now includes:
  - deep-study confidence band
  - recommendation
  - analyzed/requested source coverage
- This makes spoken/chat briefings closer to a Jarvis-style evidence summary instead of a plain ticker update.

## 3) Notification Preferences Extended
- Frontend preference API payload now supports:
  - `autonomous_stage_alerts`
  - `autonomous_stage_interval_seconds`
- Channel-configuration command flow now enables:
  - autonomous mode alerts
  - stage alerts with cadence aligned to briefing interval

## 4) Multi-Channel Awareness Behavior
- Backend notification system already supports channel adapters and channel settings for:
  - Email
  - SMS
  - WhatsApp
  - Telegram/Discord/Webhook/In-app
- Stage-awareness events now flow into that channel system with deep-study context.

## Channel Setup Checklist
- Configure notification channels via app command or preferences endpoint.
- Provide destination settings:
  - `email_to`
  - `phone_number`
  - `whatsapp_number`
  - optional `sms_webhook_url` / `whatsapp_webhook_url`
- Configure backend environment for delivery adapters:
  - SMTP: `SMTP_HOST`, `SMTP_PORT`, `SMTP_USER`, `SMTP_PASS`, `SMTP_FROM`
  - Telegram/Discord/Webhooks as needed

## High-Impact Next Upgrades
- Add delivery receipts and retries with dead-letter queue for failed SMS/WhatsApp.
- Add policy-based escalation:
  - notify-only -> suggestive autonomy -> guarded execution -> full-auto
- Add an incident timeline panel showing:
  - stage transitions
  - guardrail triggers
  - sent channel alerts
  - delivery result per channel.
