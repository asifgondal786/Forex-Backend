# Vercel + Railway + Firebase Auth + Brevo

## No Firebase Hosting
Firebase Hosting has been removed from this repository.

- Deleted: `.firebaserc`
- Deleted: `firebase.json`
- Deleted: legacy hosting artifacts under `.firebase/` and `public/`
- Do not reintroduce Firebase Hosting deploy steps in CI/CD.

## Architecture
- Frontend hosting: Vercel (Flutter Web)
- Backend hosting: Railway (FastAPI)
- Authentication: Firebase Auth only
- Transactional mail: Brevo

## Environment Variables

### Frontend (Vercel)

| Variable | Required | Example | Notes |
|---|---|---|---|
| `APP_WEB_URL` | Yes | `https://forex-frontend.vercel.app` | Canonical frontend URL used for auth redirect flows |
| `API_BASE_URL` | Yes | `https://your-backend.up.railway.app` | Railway backend URL |
| `FIREBASE_API_KEY` | Yes | `...` | Firebase Web config |
| `FIREBASE_AUTH_DOMAIN` | Yes | `<project>.firebaseapp.com` | Firebase Auth domain value (env only, not hardcoded in code) |
| `FIREBASE_PROJECT_ID` | Yes | `forexcompanion-e5a28` | Firebase project id |
| `FIREBASE_APP_ID` | Yes | `...` | Firebase Web app id |
| `FIREBASE_MESSAGING_SENDER_ID` | Yes | `...` | Firebase sender id |
| `FIREBASE_STORAGE_BUCKET` | Yes | `...` | Firebase storage bucket |
| `FIREBASE_DATABASE_URL` | Optional | `...` | If RTDB is used |
| `FIREBASE_MEASUREMENT_ID` | Optional | `...` | If Analytics is used |

### Backend (Railway)

| Variable | Required | Example | Notes |
|---|---|---|---|
| `FRONTEND_APP_URL` | Yes | `https://forex-frontend.vercel.app` | Redirect allowlist base |
| `PASSWORD_RESET_CONTINUE_URL` | Yes | `https://forex-frontend.vercel.app/reset` | Must be allowlisted and path-locked |
| `EMAIL_VERIFICATION_CONTINUE_URL` | Yes | `https://forex-frontend.vercel.app/verify` | Must be allowlisted and path-locked |
| `CORS_ORIGINS` | Yes | `https://forex-frontend.vercel.app` | Add localhost only in dev |
| `EMAIL_PROVIDER` | Yes | `brevo` | Primary provider |
| `BREVO_API_KEY` | Yes | `...` | Brevo API key |
| `BREVO_FROM_EMAIL` | Yes | `forexcompanionauto@gmail.com` | Verified sender |
| `BREVO_FROM_NAME` | Yes | `Forex Companion` | Display sender name |
| `BREVO_REPLY_TO` | Yes | `forexcompanionauto@gmail.com` | Reply-to address |
| `REDIRECT_ALLOWLIST` | Recommended | `https://forex-frontend.vercel.app,...` | Additional redirect guards |
| `AUTH_RATE_LIMIT_ENABLED` | Recommended | `true` | Auth endpoint protection |
| `AUTH_RATE_LIMIT_MAX` | Recommended | `10` | Requests per window per endpoint/IP |
| `AUTH_RATE_LIMIT_WINDOW_SECONDS` | Recommended | `300` | Auth rate-limit window |
| `CORS_MAX_AGE_SECONDS` | Recommended | `86400` | Preflight cache |

## Firebase Authorized Domains (Auth Console)

In Firebase Console -> Authentication -> Settings -> Authorized domains:

1. Keep your Vercel domain (for example `forex-frontend.vercel.app`)
2. Keep `localhost` for local development only
3. Remove unrelated domains from other apps/projects
4. Confirm email action flows return to `APP_WEB_URL` paths only (`/verify`, `/reset`)

## Brevo Redirect Consistency

1. Backend generates auth links with redirect targets from env only.
2. Verification redirects are locked to: `EMAIL_VERIFICATION_CONTINUE_URL` (`/verify`)
3. Reset redirects are locked to: `PASSWORD_RESET_CONTINUE_URL` (`/reset`)
4. Runtime guard rejects redirects outside allowlisted domains.
5. Use Brevo sender identity that is active/verified.

## Vercel Routing

`vercel.json` rewrites all paths to `index.html` for Flutter SPA routes.

### Canonical Config (Single Source)

- Keep only one Vercel config file at repo root: `vercel.json`
- Do not keep a second `Frontend/vercel.json`
- In Vercel project settings, set **Root Directory** to repository root (`.`) so root `vercel.json` is used
- Auth email links are emitted as Flutter hash-routes (for example `/#/reset?...`) to avoid path-based 404s.
- CI guard enforces this policy on every push/PR:
  - Workflow: `.github/workflows/vercel-config-guard.yml`
  - Script: `scripts/check_vercel_config.ps1`

Deep-link smoke test:

```powershell
powershell -ExecutionPolicy Bypass -File scripts/smoke_test_vercel_routes.ps1 -BaseUrl https://forex-frontend.vercel.app
```

It checks refresh behavior for:
- `/verify`
- `/reset`

## 5-Step Release Checklist

1. Set/verify all Vercel env vars (`APP_WEB_URL`, `API_BASE_URL`, Firebase web keys).
2. Set/verify all Railway env vars (redirect URLs, CORS, Brevo keys, rate limits).
3. Confirm Firebase Authorized Domains contain only Vercel domain + localhost (dev).
4. Run smoke tests:
   - `GET /auth/email-provider-status`
   - signup verification email flow
   - password reset email flow
   - deep-link refresh test script
5. Rotate old provider keys (Mailjet/Firebase legacy secrets) and redeploy.
