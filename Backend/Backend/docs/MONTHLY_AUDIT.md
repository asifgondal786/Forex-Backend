# Monthly Security Audit Checklist

Run on the first Monday of each month.

## Git And Repository Security

- [ ] Review recent commits: `git log --oneline -50`
- [ ] Scan history for leaked key signatures:
  - [ ] `git log --all -p -S "AIzaSy"`
  - [ ] `git log --all -p -S "xkeysib"`
- [ ] Verify no local env files are tracked: `git ls-files | grep -E "^\\.env($|\\..*\\.local$)"`
- [ ] Confirm `.gitignore` still blocks local secret files.

## Configuration Review

- [ ] Compare `.env.production.example` with current deployment variable set.
- [ ] Validate local config logic: `python -m app.config.validate_env --json`
- [ ] Verify production enforces:
  - [ ] `DEBUG=false`
  - [ ] `CORS_ALLOW_ALL=false`
  - [ ] `AUTH_RATE_LIMIT_ENABLED=true`
  - [ ] `RATE_LIMIT_ENABLED=true`

## Access And Permissions

- [ ] Review repository collaborators and least-privilege access.
- [ ] Review Railway project access.
- [ ] Review Sentry access.
- [ ] Review Firebase service-account roles.

## Monitoring And Alerts

- [ ] Check Sentry unresolved issues.
- [ ] Check Railway CPU/memory/error rate alerts.
- [ ] Check audit logs for abnormal auth activity.
- [ ] Check rate limit exceed logs for abuse patterns.

## Dependency And Supply Chain

- [ ] Run dependency scan: `safety check --full-report`
- [ ] Review actionable vulnerabilities.
- [ ] Create upgrade action items for vulnerable packages.

## Credentials And Secrets

- [ ] Confirm active secrets are only in secret manager.
- [ ] Confirm old rotated secrets are revoked.
- [ ] Confirm no secrets in logs or docs.

## Sign-Off

- Auditor:
- Date:
- Summary:
- Action items:
