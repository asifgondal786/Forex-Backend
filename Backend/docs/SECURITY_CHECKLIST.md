# Security Checklist

## Development

- [ ] Keep secrets in `.env.local` or `.env.development.local` only.
- [ ] Never commit real secrets.
- [ ] Run `python -m app.config.validate_env --json` before push.
- [ ] Ensure `.githooks/pre-commit` is installed.
- [ ] Avoid logging request bodies with credentials.

## Code Review

- [ ] No hardcoded keys/tokens/passwords.
- [ ] CORS settings appropriate for environment.
- [ ] Rate limiting enabled in production.
- [ ] Security headers active in production.
- [ ] Auth-gated endpoints are actually authenticated.

## Deployment

- [ ] Production secrets set in Railway.
- [ ] App starts with valid config snapshot.
- [ ] No startup log contains key material.
- [ ] Sentry/monitoring configured and healthy.
- [ ] Alerting thresholds are set and tested.

## Post-Deployment

- [ ] Health endpoints green.
- [ ] Error rates normal.
- [ ] Audit logs contain expected entries only.
- [ ] No unusual rate-limit spikes.

## Ongoing

- [ ] Monthly audit completed and archived.
- [ ] Dependency scan reviewed.
- [ ] Credential rotation schedule maintained.
