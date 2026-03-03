# Incident Response Plan

Use this when credentials, tokens, or key material are suspected to be exposed.

## Immediate Response (Within 1 Hour)

1. Identify exposed credential type and exposure scope.
2. Revoke exposed credential immediately.
3. Issue replacement credential.
4. Update secret manager values (Railway or equivalent).
5. Redeploy and verify health.
6. Notify engineering/security stakeholders.

## Credential-Specific Runbook

### Firebase

1. Firebase Console -> Project Settings -> Service Accounts.
2. Disable/delete exposed account/key.
3. Generate replacement credentials.
4. Update `FIREBASE_*` secrets.
5. Redeploy and verify auth flows.

### Brevo

1. Brevo Dashboard -> API Keys.
2. Revoke exposed key.
3. Generate replacement key.
4. Update `BREVO_API_KEY`.
5. Redeploy and test transactional email.

### Gemini

1. Google AI Studio -> API keys.
2. Revoke exposed key.
3. Generate replacement key.
4. Update `GEMINI_API_KEY`.
5. Redeploy and verify AI routes.

## If Exposure Reached Git History

1. Rewrite history (`git filter-repo`) and remove leaked values.
2. Force-push with lease.
3. Publish team sync instructions.
4. Instruct team to reset to rewritten history.

## Same-Day Follow Up

- [ ] Confirm replacement keys work.
- [ ] Confirm leaked keys are invalidated.
- [ ] Confirm no secret signatures in latest git history.
- [ ] Record incident timeline and impact.

## Next-Day Analysis

- [ ] Root cause documented.
- [ ] Preventive controls added (hook, CI, process).
- [ ] Runbook updates completed.
- [ ] Team briefing completed.

## Escalation Path

1. Team lead
2. Security owner
3. Engineering management
4. External stakeholder communications (if required)
