# Secrets Management Policy

## Storage Policy

- Production secrets must live in Railway secrets manager.
- Local developer secrets must live in `.env.local` or `.env.development.local`.
- Never commit secrets to git, docs, chat, screenshots, or PDFs.

## Rotation Policy

- Rotate API credentials at least quarterly.
- Rotate immediately after any leak, accidental commit, or unknown exposure.
- Revoke old credentials after successful rollout of new values.

## Incident Procedure (Credential Leak)

1. Revoke leaked credential immediately.
2. Generate replacement credential.
3. Update Railway secret.
4. Deploy and verify service health.
5. Remove leaked value from repository history if needed.
6. Record incident summary and prevention action.

## Commit Safety

Before pushing:

```powershell
python -m app.config.validate_env --json
git grep -n "xkeysib\|AIzaSy\|BEGIN PRIVATE KEY" .
```

If GitHub Push Protection blocks a push, remove secrets from the local commit history and recommit sanitized files.
If repository history has been rewritten, follow `HISTORY_REWRITE_NOTICE.md` before continuing work.

## Minimum Secret Set

- `FIREBASE_API_KEY`
- `FIREBASE_SERVICE_ACCOUNT_JSON_B64` (or approved alternative)
- `BREVO_API_KEY`
- `GEMINI_API_KEY` (if AI routes enabled)

## Controls

- Enable repository pre-commit hook: `.githooks/pre-commit`
- Keep CI security workflow passing: `.github/workflows/security-scan.yml`
