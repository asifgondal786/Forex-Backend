# Security Overview

## Security objectives
- Protect user credentials and broker-linked secrets.
- Prevent unauthorized API/WebSocket access.
- Enforce safe trading boundaries in autonomous scenarios.
- Reduce leakage of sensitive data in transit, logs, and UI.

## Implemented controls

### Authentication and authorization
- Backend validates API and WebSocket identity through token-based checks.
- Dev identity fallback is explicit and environment-gated.
- User-scoped operations validate requester ownership for sensitive endpoints.

### Transport and origin controls
- Security headers are applied on backend responses.
- CORS is environment-controlled; production expects explicit allowed origins.
- Optional trusted host restrictions are supported via configuration.
- WebSocket auth validates user-token consistency.

### Abuse and resource controls
- HTTP rate limiting middleware is enabled by default.
- WebSocket connection rate limiting is enabled.
- Request body size limiting is supported for API endpoints.

### Secret and credential protection
- Encrypted credential vault support for broker credentials.
- Non-debug mode requires persistent vault key configuration.
- UI masks sensitive fields in admin areas by default.

### Trading safety and governance
- Guardrails enforce risk-per-trade and loss limits.
- Explain-before-execute and kill-switch patterns are supported.
- Compliance/legal acknowledgment services and audit logging are available.

## Recommended production baseline

### Backend
- `DEBUG=false`
- `ALLOW_DEV_USER_ID=false`
- `CORS_ORIGINS` set to exact production frontend domain(s)
- `ALLOWED_HOSTS` set to exact backend domain(s)
- `ENABLE_HSTS=true`
- `ENABLE_CSP=true`
- `MAX_REQUEST_BODY_BYTES` set to a strict value
- `CREDENTIAL_VAULT_MASTER_KEY` configured
- `REQUIRE_FIREBASE=true` with valid service account credentials

### Frontend build
- Use `https://` API base URL and `wss://` WebSocket base URL
- Disable debug fallback flags in release
- Keep auth gate enabled in release
- Avoid embedding private keys or provider secrets in client code

## Operational recommendations
- Rotate secrets regularly (vault keys, provider tokens, SMTP/webhook keys).
- Add centralized logging + alerting for failed auth and unusual trading events.
- Add dependency and container/image scanning in CI.
- Perform staged rollout: paper mode, limited beta, then guarded live release.
- Conduct periodic penetration testing before broad production launch.

## Scope note
No software system can be made "unhackable." The goal is defense-in-depth: reduce attack surface, limit blast radius, and detect/respond quickly.

