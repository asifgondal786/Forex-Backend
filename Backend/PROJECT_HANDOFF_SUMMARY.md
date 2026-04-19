# 📋 Tajir — Forex Companion AI App
## Hands-Off Project Summary & Remaining To-Do List
**Generated:** April 19, 2026  
**Git HEAD:** `f234a751` (main branch, synced with `origin/main`)  
**Remote:** https://github.com/asifgondal786/Forex-Backend.git  
**Deployment Target:** Oracle Cloud VM (via GitHub Actions SSH) + Railway (Docker)

---

## 🏗️ Project Architecture Overview

```
d:\Tajir\
├── Backend/          ← FastAPI Python backend (Python 3.12)
│   ├── app/          ← Main application package
│   │   ├── main.py   ← FastAPI app entry point (1,403 lines)
│   │   ├── routers/  ← Sub-routers (ai_proxy, charting, notifications, security)
│   │   ├── services/ ← Business logic (30+ services)
│   │   ├── models/   ← Pydantic/DB models
│   │   ├── risk/     ← Risk Guardian system
│   │   ├── config/   ← Environment config, logging, validation
│   │   ├── middleware/← Observability, audit middleware
│   │   └── utils/    ← Firestore client, helpers
│   ├── tests/        ← pytest test suite
│   ├── migrations/   ← SQL migration files
│   ├── scripts/      ← Data collector, model trainer
│   ├── Dockerfile    ← Python 3.12-slim, port 8080
│   ├── railway.json  ← Railway deployment config
│   ├── requirements.txt ← 176 Python dependencies
│   └── .env          ← Local dev secrets (DO NOT COMMIT)
│
├── Frontend/         ← Flutter app (Dart, SDK >=3.6.0)
│   ├── lib/
│   │   ├── main.dart ← App entry point
│   │   ├── app_shell.dart ← Main shell with bottom nav
│   │   ├── features/ ← Feature-based structure
│   │   │   ├── auth/         ← Login, Signup, AuthGate
│   │   │   ├── dashboard/    ← Home screen, widgets, dialogs
│   │   │   ├── ai_chat/      ← AI chat screen
│   │   │   ├── charts/       ← TradingView chart screen
│   │   │   ├── trade_signals/← Signal display
│   │   │   ├── automation/   ← Automation rules
│   │   │   └── settings/     ← Settings, broker connect
│   │   ├── providers/        ← 20+ Provider state managers
│   │   ├── services/         ← API, Firebase, WebSocket, etc.
│   │   ├── core/             ← Models, theme, widgets, utils
│   │   └── shared/           ← Reusable widgets
│   ├── assets/
│   │   ├── images/robo.png
│   │   └── tradingview_chart.html ← TradingView embed
│   ├── web/firebase-config.js
│   └── pubspec.yaml  ← Flutter dependencies
│
├── .github/workflows/deploy.yml ← CI/CD to Oracle Cloud
├── scripts/          ← Python utility/patch scripts
└── firebase.json     ← Firebase hosting config
```

---

## 🔑 Credentials & Services Inventory

### Currently Configured (in `Backend/.env`)
| Service | Status | Notes |
|---------|--------|-------|
| **Supabase** | ✅ Configured | PostgreSQL DB + Auth. URL: `vlmenitpmbibbqdlsick.supabase.co` |
| **Firebase** | ✅ Configured | Project: `forexcompanion-e5a28`. Key path: `D:\forexcompanion-e5a28-b416ac20257f.json` |
| **DeepSeek AI** | ✅ Configured | `AI_ROUTES_AVAILABLE=true` |
| **Twelve Data** | ✅ Configured | Forex market data API |
| **Brevo (Email)** | ✅ Configured | Email provider for verification/reset |
| **Twilio** | ✅ Configured | SMS/2FA. Account: `AC2cb28072...` |
| **Redis** | ⚠️ Local Only | `redis://localhost:6379` — needs cloud Redis for production |
| **Pepperstone FIX** | ✅ Configured | Demo account `5272744`, cTrader demo server |
| **JWT** | ✅ Configured | Secret key set |
| **Sentry** | ⚠️ Not in .env | DSN not configured — errors won't be tracked in production |
| **Gemini AI** | ⚠️ Partial | `gemini_client.py` exists, key not in .env |
| **FCS API** | ❌ Missing | `FCS_API_KEY` not set |
| **Finnhub** | ❌ Missing | `FINNHUB_KEY` not set |
| **iTick** | ❌ Missing | `ITICK_API_KEY` not set |

### GitHub Actions Secrets Required (for CI/CD deploy)
The `deploy.yml` workflow requires these secrets set in GitHub repo settings:
- `ORACLE_HOST`, `ORACLE_USER`, `ORACLE_SSH_KEY`, `ORACLE_PORT`
- `FIREBASE_API_KEY`, `FIREBASE_APP_ID`, `FIREBASE_MESSAGING_SENDER_ID`
- `FIREBASE_PROJECT_ID`, `FIREBASE_AUTH_DOMAIN`, `FIREBASE_DATEBASE_URL`
- `FIREBASE_STORAGE_BUCKET`, `FIREBASE_MEASUREMENT_ID`
- `DEEP_SEEK_API_KEY`, `SUPABASE_SERVICE_ROLE_KEY`, `SUPABASE_URL`, `SUPABASE_ANON_KEY`
- `TWELVE_DATA_API_KEY`, `BREVO_API_KEY`, `JWT_SECRET_KEY`, `REDIS_URL`
- `TWILIO_ACCOUNT_SID`, `TWILIO_AUTH_TOKEN`, `TWILIO_PHONE_NUMBER`
- `DATABASE_URL`

---

## ✅ What Is COMPLETE (Production-Ready)

### Backend — Fully Implemented
| Module | Status | Description |
|--------|--------|-------------|
| FastAPI App (`main.py`) | ✅ Complete | Full middleware stack: CORS, CSP, HSTS, rate limiting, request ID, envelope |
| Authentication | ✅ Complete | Firebase Auth + JWT, 2FA/TOTP, device verification |
| User Management | ✅ Complete | CRUD, profiles, settings |
| Market Data | ✅ Complete | Twelve Data integration, OHLC, rates, snapshot |
| Trade Signals | ✅ Complete | Signal generation, NLP parsing, technical indicators |
| Risk Guardian | ✅ Complete | Risk models, middleware, Kelly criterion, stress test, drawdown |
| Paper Trading | ✅ Complete | Open/close trades, history, performance metrics |
| Portfolio | ✅ Complete | Portfolio routes, P&L tracking |
| Automation | ✅ Complete | Automation rules engine |
| Notifications | ✅ Complete | Push (FCM), SMS (Twilio), Email (Brevo), dispatcher |
| AI Chat / Task Routes | ✅ Complete | DeepSeek proxy, Gemini client, AI task engine |
| WebSocket | ✅ Complete | Enhanced WS manager, forex stream, live updates |
| Macro Shield | ✅ Complete | Economic event scraper, macro routes, shield scheduler |
| Security | ✅ Complete | Security routes, compliance service, key vault |
| Observability | ✅ Complete | Health checks, monitoring routes, Sentry integration |
| Rate Limiting | ✅ Complete | slowapi + custom in-memory limiter |
| Charting | ✅ Complete | Charting router, mock candle generator |
| Social | ✅ Complete | Social routes |
| Subscription | ✅ Complete | Subscription routes |
| Credential Vault | ✅ Complete | Credential vault routes |
| Ops Routes | ✅ Complete | Ops/admin endpoints |
| Docker | ✅ Complete | `Dockerfile` with Python 3.12-slim, port 8080 |
| Railway Config | ✅ Complete | `railway.json` with health check |
| CI/CD | ✅ Complete | GitHub Actions → Oracle Cloud SSH deploy |

### Frontend — Fully Implemented
| Feature | Status | Description |
|---------|--------|-------------|
| Auth Flow | ✅ Complete | Login, Signup, AuthGate with Firebase |
| Dashboard | ✅ Complete | Home screen, stat cards, task list |
| AI Chat | ✅ Complete | Chat screen with AI responses |
| Charts | ✅ Complete | TradingView embed via InAppWebView |
| Trade Signals | ✅ Complete | Signal display with provider |
| Automation | ✅ Complete | Automation rules screen |
| Settings | ✅ Complete | Settings screen, broker connect sheet |
| Notifications | ✅ Complete | Notification sheet, FCM integration |
| Paper Trading | ✅ Complete | Paper trading provider + UI |
| Risk Provider | ✅ Complete | Risk state management |
| Market Watch | ✅ Complete | Market watch provider |
| Portfolio | ✅ Complete | Portfolio provider |
| 2FA Security | ✅ Complete | TOTP setup + login screens |
| Quick Actions | ✅ Complete | Quick actions overlay |
| Bottom Nav | ✅ Complete | Bottom navigation bar |
| Connection Banner | ✅ Complete | Offline/online status banner |
| Skeleton Loaders | ✅ Complete | Loading states |
| Error States | ✅ Complete | Error state widget |
| Sentry | ✅ Complete | `sentry_service.dart` integrated |
| Theme | ✅ Complete | Dark theme (#0F1419), app colors |
| **Phase A Engagement** | ✅ Complete | Intelligent empty states, trust footer, language upgrade |
| **Phase 3 Gamification** | ✅ Complete | Sentiment radar, sleep mode, market replay, learning indicator, performance dashboard |

---

## 🟡 What Is PARTIALLY DONE (Needs Completion)

### 1. Phase B Engagement Features (Frontend + Light Backend)
**Status:** Designed, NOT implemented  
**Effort:** ~7 hours  
**Files to create:**
- `Frontend/lib/features/dashboard/widgets/ai_activity_feed.dart`
- `Frontend/lib/features/dashboard/widgets/confidence_evolution.dart`
- `Frontend/lib/features/dashboard/widgets/contextual_risk_alerts.dart`
- `Backend/app/api/ai_activity_routes.py`
- `Backend/app/api/ai_insights_routes.py`

**Backend endpoints needed:**
```
GET /api/ai/activity-feed?limit=10
GET /api/ai/confidence-history?period=24h
GET /api/ai/alerts?active=true
```

### 2. Phase C Deep Engagement (Frontend + Full Backend)
**Status:** Designed, NOT implemented  
**Effort:** ~9.5 hours  
**Files to create:**
- `Frontend/lib/features/dashboard/widgets/ai_explanation_drawer.dart`
- `Frontend/lib/features/dashboard/widgets/ai_nudge_system.dart`
- `Frontend/lib/features/dashboard/widgets/progress_feedback.dart`
- `Frontend/lib/providers/nudge_provider.dart`
- `Backend/app/services/explanation_service.py`
- `Backend/app/services/nudge_service.py`

**Backend endpoints needed:**
```
POST /api/ai/explain-decision
GET /api/ai/nudges?context=active
POST /api/ai/nudge-response
GET /api/user/progress?period=week
GET /api/user/achievements
```

### 3. Phase 3 Dashboard Integration
**Status:** Components built, NOT wired into dashboard  
**Effort:** ~45 minutes  
**What's needed:**
- Import `sentiment_radar.dart`, `sleep_mode.dart`, `market_replay.dart`, `learning_indicator.dart`, `performance_score_dashboard.dart` into `dashboard_screen_enhanced.dart`
- Create `Phase3Provider` for state management
- Connect real data from existing providers

### 4. Redis — Production Configuration
**Status:** Currently `redis://localhost:6379` (local only)  
**What's needed:**
- Provision a cloud Redis instance (Railway Redis, Upstash, or Redis Cloud)
- Update `REDIS_URL` in production `.env` / GitHub Secrets
- Test Redis-dependent features: rate limiting, task queue, WebSocket state

### 5. Production Environment Variables
**Status:** `.env` is in development mode (`DEBUG=true`, `ENVIRONMENT=development`)  
**What's needed for production:**
- Set `DEBUG=false`, `ENVIRONMENT=production`
- Set `FRONTEND_APP_URL` to actual production URL (HTTPS)
- Set `PASSWORD_RESET_CONTINUE_URL` and `EMAIL_VERIFICATION_CONTINUE_URL` to production URLs
- Set `CORS_EXTRA_ORIGINS` to production frontend domain
- Remove `CORS_ALLOW_ALL` / ensure it's `false`
- Set `SENTRY_DSN` for error tracking
- Set `FIREBASE_KEY_PATH` to production service account path (or use `FIREBASE_SERVICE_ACCOUNT_JSON_B64`)

### 6. Firebase Auth Authorized Domains
**Status:** Needs production domain added  
**What's needed:**
- Go to Firebase Console → Authentication → Settings → Authorized Domains
- Add the production frontend domain (e.g., `tajir.app` or Railway/Oracle domain)

### 7. Missing API Keys
**Status:** Not configured  
**What's needed:**
- `FCS_API_KEY` — FCS Forex data (optional fallback)
- `FINNHUB_KEY` — Finnhub market data (optional fallback)
- `ITICK_API_KEY` — iTick data (optional fallback)
- `GEMINI_API_KEY` — Google Gemini AI (if using Gemini alongside DeepSeek)
- `SENTRY_DSN` — Error monitoring

---

## ❌ What Is NOT Done (Remaining Work)

### Backend
| Task | Priority | Effort | Notes |
|------|----------|--------|-------|
| Phase B backend endpoints (activity feed, confidence, alerts) | 🔴 High | 3h | Needed for Phase B frontend |
| Phase C backend endpoints (explain, nudge, progress) | 🟠 Medium | 5h | Needed for Phase C frontend |
| Unit tests for core services | 🟠 Medium | 4h | `tests/` has some tests but coverage is incomplete |
| Database migrations run on production | 🔴 High | 1h | `migrations/migration_risk_audit_log.sql` needs to be applied |
| Production `.env` configuration | 🔴 Critical | 1h | See section above |
| Cloud Redis provisioning | 🔴 High | 0.5h | Required for production rate limiting + task queue |
| Sentry DSN configuration | 🟠 Medium | 0.5h | Error tracking in production |
| Remove duplicate rate limiter registration | 🟡 Low | 0.1h | `main.py` lines 607-618 register slowapi twice |
| `railway.json` startCommand is empty | 🟡 Low | 0.1h | Should be `uvicorn app.main:app --host 0.0.0.0 --port ${PORT:-8080}` |

### Frontend
| Task | Priority | Effort | Notes |
|------|----------|--------|-------|
| Phase B widgets (activity feed, confidence, risk alerts) | 🔴 High | 4h | See ENGAGEMENT_ROADMAP.md |
| Phase C widgets (explanation drawer, nudge system, progress) | 🟠 Medium | 5.5h | See ENGAGEMENT_ROADMAP.md |
| Phase 3 dashboard integration | 🟠 Medium | 0.75h | Wire 5 gamification widgets into dashboard |
| Unit/widget tests | 🟠 Medium | 3h | No tests currently in `test/` |
| Flutter build for production (web/Android/iOS) | 🔴 High | 1h | `flutter build web` or `flutter build apk` |
| Firebase Hosting deploy (web) | 🟠 Medium | 0.5h | `firebase deploy` from `Frontend/` |
| Production API URL configuration | 🔴 Critical | 0.5h | `runtime_url_resolver.dart` must point to production backend |
| Voice service integration | 🟡 Low | 2h | `scripts/patch_voice.py` and `write_voice_service.py` exist but not integrated |

### DevOps / Infrastructure
| Task | Priority | Effort | Notes |
|------|----------|--------|-------|
| Oracle Cloud VM setup verification | 🔴 Critical | 1h | Confirm `/home/opc/Forex-Backend` exists, venv active, systemd service running |
| `forex-backend` systemd service file | 🔴 Critical | 0.5h | Must exist on Oracle VM for `systemctl restart forex-backend` to work |
| SSL/TLS certificate on Oracle VM | 🔴 High | 1h | Nginx + Let's Encrypt for HTTPS |
| Nginx reverse proxy config | 🔴 High | 1h | Proxy port 8080 → 443 |
| GitHub Actions secrets verification | 🔴 Critical | 0.5h | All secrets must be set in repo settings |
| End-to-end deployment test | 🔴 Critical | 1h | Push to main → verify deploy succeeds |
| Monitoring/alerting setup | 🟠 Medium | 1h | Sentry + uptime monitoring |

---

## 🚀 Recommended Completion Order

### Phase 1 — Make Production Deployable (Critical, ~6 hours)
1. **Set all GitHub Actions secrets** in repo settings
2. **Provision cloud Redis** (Upstash free tier works) → update `REDIS_URL` secret
3. **Verify Oracle VM** has: venv, systemd service, nginx, SSL cert
4. **Configure production `.env`** on Oracle VM (HTTPS URLs, `DEBUG=false`, `ENVIRONMENT=production`)
5. **Run database migration** (`migration_risk_audit_log.sql`) on Supabase
6. **Add production domain** to Firebase Auth authorized domains
7. **Push to main** → verify GitHub Actions deploy succeeds
8. **Test health endpoint**: `GET https://your-domain/health`

### Phase 2 — Frontend Production Build (~2 hours)
1. Update `runtime_url_resolver.dart` with production backend URL
2. Run `flutter build web` from `Frontend/`
3. Deploy to Firebase Hosting: `firebase deploy`
4. OR build APK: `flutter build apk --release`

### Phase 3 — Phase 3 Dashboard Integration (~1 hour)
1. Import 5 gamification widgets into `dashboard_screen_enhanced.dart`
2. Create `Phase3Provider`
3. Connect real data from existing providers

### Phase 4 — Phase B Engagement Features (~7 hours)
1. Create 3 backend endpoints (activity feed, confidence history, alerts)
2. Create 3 Flutter widgets (activity feed, confidence evolution, risk alerts)
3. Wire widgets to backend via existing `api_service.dart`

### Phase 5 — Phase C Deep Engagement (~10 hours)
1. Create explanation, nudge, progress backend services + routes
2. Create Flutter widgets (explanation drawer, nudge system, progress feedback)
3. Create `nudge_provider.dart`

### Phase 6 — Testing & Polish (~5 hours)
1. Write unit tests for critical backend services
2. Write Flutter widget tests
3. Fix duplicate slowapi registration in `main.py`
4. Fix empty `startCommand` in `railway.json`
5. Configure Sentry DSN

---

## 🔧 Quick Reference Commands

### Start Backend Locally
```bash
cd d:\Tajir\Backend
# Activate venv first
python -m uvicorn app.main:app --reload --port 8080
```

### Start Frontend Locally
```bash
cd d:\Tajir\Frontend
flutter run -d chrome
# or
flutter run -d <device-id>
```

### Run Backend Tests
```bash
cd d:\Tajir\Backend
pytest tests/ -v
```

### Deploy to Oracle Cloud (manual)
```bash
# Push to main branch — GitHub Actions handles the rest
git push origin main
```

### Build Flutter Web
```bash
cd d:\Tajir\Frontend
flutter build web --release
firebase deploy
```

### Apply DB Migration
```sql
-- Run in Supabase SQL editor:
-- Contents of Backend/migrations/migration_risk_audit_log.sql
```

---

## ⚠️ Known Issues & Warnings

1. **`.env` has real secrets** — `Backend/.env` contains live API keys. Ensure it stays in `.gitignore` and is never committed.
2. **Firebase key path is Windows-absolute** — `FIREBASE_KEY_PATH="D:\forexcompanion-e5a28-b416ac20257f.json"` will fail on Linux (Oracle VM). Use `FIREBASE_SERVICE_ACCOUNT_JSON_B64` environment variable instead for production.
3. **Duplicate slowapi registration** — `main.py` lines 607-618 register the rate limiter twice. Remove the duplicate block.
4. **`railway.json` startCommand is empty** — If deploying to Railway, add: `"startCommand": "uvicorn app.main:app --host 0.0.0.0 --port ${PORT:-8080} --proxy-headers"`
5. **Redis is localhost** — All Redis-dependent features (rate limiting, task queue, WebSocket state) will fail in production without a cloud Redis URL.
6. **Phase 3 widgets not wired** — 5 gamification components exist in `Frontend/lib/features/dashboard/widgets/` but are not imported/used in the dashboard screen yet.
7. **No Flutter tests** — The `test/` directory appears empty. No automated UI testing exists.
8. **`FRONTEND_APP_URL` is localhost** — Must be changed to production HTTPS URL before going live.

---

## 📁 Key File Locations

| What | Where |
|------|-------|
| Backend entry point | `Backend/app/main.py` |
| Backend config | `Backend/app/config/index.py` |
| Backend secrets | `Backend/.env` (local only) |
| Frontend entry | `Frontend/lib/main.dart` |
| App shell | `Frontend/lib/app_shell.dart` |
| Dashboard | `Frontend/lib/features/dashboard/home_screen.dart` |
| API service | `Frontend/lib/services/api_service.dart` |
| Firebase config | `Frontend/lib/core/config/firebase_config.dart` |
| URL resolver | `Frontend/lib/core/utils/runtime_url_resolver.dart` |
| CI/CD workflow | `.github/workflows/deploy.yml` |
| Docker config | `Backend/Dockerfile` |
| Railway config | `Backend/railway.json` |
| DB migration | `Backend/migrations/migration_risk_audit_log.sql` |
| Engagement roadmap | `Frontend/ENGAGEMENT_ROADMAP.md` |
| Phase 3 guide | `Frontend/PHASE_3_IMPLEMENTATION_GUIDE.md` |
| Phase 3 quick start | `Frontend/PHASE_3_QUICK_START.md` |

---

## 📊 Project Completion Estimate

| Area | Completion |
|------|-----------|
| Backend Core API | 95% ✅ |
| Backend Production Config | 40% 🟡 |
| Frontend Features | 85% ✅ |
| Frontend Production Build | 20% 🔴 |
| Engagement Features (Phase B) | 0% 🔴 |
| Engagement Features (Phase C) | 0% 🔴 |
| Phase 3 Dashboard Integration | 80% 🟡 |
| Testing | 15% 🔴 |
| DevOps / Infrastructure | 50% 🟡 |
| **Overall** | **~60%** |

---

*This document was auto-generated by reviewing the full codebase on April 19, 2026.*  
*Update this file as tasks are completed.*
