# Deployment Guide (Railway)

## Pre-Deployment Checklist

1. Validate environment templates:
```powershell
python -m app.config.validate_env --json
```
2. Confirm no secrets are in tracked files:
```powershell
git grep -n "xkeysib\|AIzaSy\|BEGIN PRIVATE KEY" .
```
3. Ensure production flags:
- `ENVIRONMENT=production`
- `DEBUG=false`
- `CORS_ALLOW_ALL=false`
- `AUTH_RATE_LIMIT_ENABLED=true`
- `RATE_LIMIT_ENABLED=true`

## Railway Secrets

Set these in Railway Variables (Secret values):
- `FIREBASE_API_KEY`
- `FIREBASE_SERVICE_ACCOUNT_JSON_B64` (or `FIREBASE_SERVICE_ACCOUNT_PATH` if mounted)
- `BREVO_API_KEY`
- `GEMINI_API_KEY` (required if `AI_ROUTES_AVAILABLE=true`)
- `SENTRY_DSN` (recommended for production monitoring)

Do not store these values in repository files.

## Deploy Steps

```powershell
railway login
railway link
railway variables
railway deploy
railway logs --follow
```

## Runtime Verification

After deployment:

- Health endpoint responds: `/health`
- Startup log contains `env_validation` event with `ok=true`
- Startup log contains `config_snapshot` event
- No startup warning about `sentry_init_failed` when `SENTRY_DSN` is set
- No secret values appear in logs
- CORS/rate-limit behavior matches production policy
- Railway alerts are configured for CPU, memory, and error-rate thresholds

## Operational Cadence

- Weekly: run security healthcheck and review monitoring dashboards.
- Monthly: execute `docs/MONTHLY_AUDIT.md`.
- Quarterly: review strategy with `docs/PHASE_8_OPERATIONAL_EXCELLENCE.md`.
