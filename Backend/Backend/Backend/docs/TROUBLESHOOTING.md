# Troubleshooting

## `Environment validation failed` on startup

Cause:
- Required variable missing
- Production safety rule violated
- Invalid URL/CORS configuration

Fix:
1. Run `python -m app.config.validate_env --json`.
2. Correct reported variables.
3. Restart app.

## CORS blocked in production

Cause:
- `CORS_ORIGINS` missing or wrong
- Non-HTTPS origin in production

Fix:
- Set `CORS_ORIGINS` to your exact frontend origin(s), e.g.:
  `https://forexcompanion-e5a28.web.app,https://forexcompanion-e5a28.firebaseapp.com`
- Keep `CORS_ALLOW_ALL=false`.

## Email links broken

Cause:
- Wrong `FRONTEND_APP_URL` / continue URLs
- Domain typo (`forexcompanione5a28` vs `forexcompanion-e5a28`)

Fix:
- Set:
  - `FRONTEND_APP_URL=https://forexcompanion-e5a28.web.app`
  - `EMAIL_VERIFICATION_CONTINUE_URL=https://forexcompanion-e5a28.web.app/verify`
  - `PASSWORD_RESET_CONTINUE_URL=https://forexcompanion-e5a28.web.app/reset`

## Push blocked by GitHub Push Protection

Cause:
- A secret exists in staged commit(s).

Fix:
1. Remove secret values from tracked files.
2. Rewrite local commit (`git reset --soft HEAD~1`, recommit clean files).
3. Push again.

## Firebase boot failure

Cause:
- `REQUIRE_FIREBASE=true` without valid admin credentials.

Fix:
- Set one of:
  - `FIREBASE_SERVICE_ACCOUNT_JSON_B64`
  - `FIREBASE_SERVICE_ACCOUNT_JSON`
  - `FIREBASE_SERVICE_ACCOUNT_PATH`
  - `GOOGLE_APPLICATION_CREDENTIALS`

## Audit Logs Not Appearing

Cause:
- File logging disabled
- Log directory misconfigured

Fix:
1. Check `ENABLE_FILE_LOGGING=true`.
2. Check `LOG_DIR` exists or is writable.
3. Check logger output for `audit` and `config_audit` channels.

## Sentry Not Capturing Errors

Cause:
- `SENTRY_DSN` unset/invalid
- `sentry-sdk` not installed in runtime image

Fix:
1. Set valid `SENTRY_DSN` in production secrets.
2. Verify `sentry-sdk` is installed from `requirements.txt`.
3. Check startup logs for `sentry_initialized` or `sentry_init_failed`.
