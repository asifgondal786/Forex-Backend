# JWT Validation Audit Checklist (Production Certification)

Last updated: 2026-03-02

## Scope

This checklist is for the auth layer implemented in:

- `Backend/app/main.py`
- `Backend/app/security.py`
- `Backend/app/utils/firestore_client.py`
- `Backend/app/public_auth_routes.py`

## 1. Token Verification Controls

- [x] `Authorization: Bearer <token>` is required for protected APIs.
- [x] Missing/invalid tokens fail with HTTP `401`.
- [x] Firebase ID token verification is executed through `auth.verify_id_token(...)`.
- [ ] Revoked-token enforcement is enabled (`check_revoked=True`) for protected API traffic.
- [ ] Token issuer (`iss`) and audience (`aud`) are explicitly asserted against configured Firebase project values.
- [ ] Maximum token age policy is enforced (example: reject tokens older than N minutes even if not expired).

## 2. Route Protection Boundaries

- [x] Global JWT enforcement exists for `/api/*` via `strict_auth_middleware`.
- [x] Public auth routes are unauthenticated (`/auth/password-reset`, `/auth/email-verification`, `/auth/email-provider-status`).
- [ ] Public route inventory is documented and approved.
- [ ] A regression test guarantees new `/api/*` endpoints cannot ship without auth enforcement.

## 3. Development Bypass Hardening

- [x] Dev-user bypass is opt-in only (`ALLOW_DEV_USER_ID` defaults to disabled).
- [ ] Production environment explicitly sets `ALLOW_DEV_USER_ID=false`.
- [ ] Production environment explicitly sets `DEV_USER_LOCALHOST_ONLY=true`.
- [ ] If bypass is ever enabled outside local, `DEV_AUTH_SHARED_SECRET` is mandatory and rotated.

## 4. Authorization (Claims-to-Action)

- [ ] Role/claim checks exist for privileged operations (admin/ops/monitoring).
- [ ] User-scoped resources enforce ownership (`uid` must match route/body target user).
- [ ] Sensitive actions require explicit claim gates, not only "token is valid".

## 5. Credential and Key Management

- [x] Firebase Admin credential source and project identity checks are present.
- [ ] Service account key rotation policy is documented and scheduled.
- [ ] Service account permissions are least-privilege (no broad Editor/Owner roles).
- [ ] Firebase project mismatch is treated as deploy-blocking in production.

## 6. Logging, Monitoring, and Alerting

- [x] Request correlation ID (`X-Request-ID`) is attached.
- [ ] Auth failures are structured-logged with reason class (missing token, invalid token, revoked token, claim denied).
- [ ] Alerts exist for spikes in `401/403`, token verification failures, and auth route abuse.
- [ ] On-call runbook includes key compromise and token abuse response steps.

## 7. Security Test Matrix (Must Pass)

- [ ] Missing token on protected endpoint returns `401`.
- [ ] Malformed bearer token returns `401`.
- [ ] Expired token returns `401`.
- [ ] Revoked token returns `401`.
- [ ] Token from wrong Firebase project returns `401`.
- [ ] Valid token with insufficient claim/role returns `403`.
- [ ] `/auth/password-reset` works without auth and is not blocked by JWT middleware.
- [ ] Preflight `OPTIONS` for auth endpoints succeeds with expected CORS headers.

## 8. Certification Gate

Mark production-certified only when all items below are complete:

- [ ] All unchecked items in sections 1-7 are closed.
- [ ] Automated auth regression tests are green in CI.
- [ ] Security review sign-off completed.
- [ ] Production environment variables verified and recorded.

## Quick Validation Commands

Replace `BASE_URL` and `TOKEN` before running.

```bash
# 1) Protected endpoint must reject missing token
curl -i "$BASE_URL/api/auth/status"

# 2) Protected endpoint must accept valid token
curl -i "$BASE_URL/api/auth/status" -H "Authorization: Bearer $TOKEN"

# 3) Public password reset endpoint must not require Authorization
curl -i "$BASE_URL/auth/password-reset" \
  -H "Content-Type: application/json" \
  -d '{"email":"test@example.com"}'

# 4) Preflight should return CORS headers
curl -i -X OPTIONS "$BASE_URL/auth/password-reset" \
  -H "Origin: https://forexcompanion-e5a28.web.app" \
  -H "Access-Control-Request-Method: POST" \
  -H "Access-Control-Request-Headers: content-type"
```
