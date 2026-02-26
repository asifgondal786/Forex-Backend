# Phase 7: Final Deployment & Validation Guide

## Pre-Deployment Validation (Run This First)

### 1. Run Auth Validator
```bash
cd Backend
python -m app.validators.auth_validator
```

**Expected Output**:
```
PHASE 7: AUTH VALIDATION REPORT
============================================================
Total Endpoints Scanned: 50+
Protected Endpoints: 48
Unprotected Endpoints: 2  # (login, health should be public)

Issues Found: 0
Critical Issues: 0

✓ All endpoints properly authenticated!
✓ Phase 7 Auth Validation: PASSED
```

### 2. Run Phase 6 Tests (Should All Pass)
```bash
cd Backend
python -m pytest tests/test_phase6_observability.py -v
```

**Expected**: ✓ 34/34 PASSED

### 3. Test Rate Limiting
```bash
TOKEN="your-test-token"

# Test protected endpoint
curl -H "Authorization: Bearer $TOKEN" \
  http://localhost:8000/api/accounts/connections

# Test rate limit by sending 150 requests
for i in {1..150}; do
  curl -s -H "Authorization: Bearer $TOKEN" \
    http://localhost:8000/api/ai-task/status > /dev/null &
done
wait

# Should see some 429 responses after 10 requests/minute
```

### 4. Verify Firestore Security Rules
```bash
cd Backend
# Deploy rules
firebase deploy --only firestore:rules

# Verify in Firebase Console:
# Security Rules > Test Rules
# Create simulation test for read/write as different users
```

### 5. Verify Database Indexes
```bash
cd Backend
# Deploy indexes
firebase deploy --only firestore:indexes

# Monitor progress at:
# Firebase Console > Firestore > Indexes
```

---

## Deployment Checklist

### Frontend Deployment (Vercel)

- [ ] **Security Headers Check**
```bash
# After deploying to Vercel
curl -I https://your-vercel-domain.com | grep -i "strict-transport-security"
# Should show: Strict-Transport-Security: max-age=...
```

- [ ] **Token Storage Verification**
  - [ ] No sensitive data logged to console
  - [ ] Tokens only in localStorage with expiry
  - [ ] HTTPS enforced on all requests
  - [ ] CORS properly configured

- [ ] **Environment Variables Set**
  - [ ] VITE_API_BASE_URL="https://your-railway-domain"
  - [ ] NODE_ENV=production

- [ ] **Build Succeeds**
```bash
cd Frontend
npm run build
# Should complete without errors
```

### Backend Deployment (Railway)

- [ ] **Environment Variables Configured**
```
FIREBASE_PROJECT_ID=your-project
FIREBASE_PRIVATE_KEY=...
FIREBASE_CLIENT_EMAIL=...
REDIS_URL=redis://...  # Optional
ALLOW_DEV_USER_ID=false
SUBSCRIPTION_PAYWALL_ENABLED=true
``` 

- [ ] **Auth Middleware Enabled**
```python
# app/main.py should have:
app.add_middleware(AuthMiddleware)  # Before routes
```

- [ ] **Rate Limiting Active**
```python
# app/main.py should have:
app.add_middleware(RateLimitingMiddleware)  # For API routes
```

- [ ] **Phase 6 Monitoring Active**
```bash
# Check endpoint
curl http://localhost:8000/api/monitoring/health
# Should return healthy status
```

- [ ] **Tests Passing**
```bash
pytest tests/test_phase6_observability.py -v
# All 34 tests should pass
```

### Database (Firestore)

- [ ] **Security Rules Deployed**
```bash
firebase deploy --only firestore:rules
# Verify: firebase firestore:access-grant list
```

- [ ] **Indexes Created**
```bash
firebase deploy --only firestore:indexes
# Monitor: Firestore Console > Indexes
# Wait for "Index creation in progress" to complete
```

- [ ] **Collections Structure Verified**
  - [ ] /users/{userId}
  - [ ] /subscriptions/{userId}
  - [ ] /trading/{userId}/{document}
  - [ ] /notifications/{userId}/messages/{messageId}
  - [ ] /accounts/{userId}/accounts/{accountId}

---

## Production Verification Tests

### Test 1: Authentication on Protected Endpoints
```bash
# Should fail without token
curl -X GET http://localhost:8000/api/accounts/connections
# Expected: 401 Unauthorized

# Should succeed with token
curl -X GET \
  -H "Authorization: Bearer YOUR_TOKEN" \
  http://localhost:8000/api/accounts/connections
# Expected: 200 OK or 403 Forbidden (subscription check)
```

### Test 2: Rate Limiting
```bash
TOKEN="your-token"

# Send 100 requests in parallel
for i in {1..100}; do
  curl -s -H "Authorization: Bearer $TOKEN" \
    http://localhost:8000/api/forecast > /dev/null &
done
wait

# After ~10 requests, should get:
# 429 Too Many Requests
```

### Test 3: Database Security Rules
```javascript
// In Firebase Console > Firestore > Test Rules

// Test 1: User can read own data
db.collection('users').doc('user123').get()
// user: user123 -> Should: ALLOW
// user: user456 -> Should: DENY

// Test 2: User cannot write to others' subscriptions
db.collection('subscriptions').doc('user456').set({})
// user: user123 -> Should: DENY (security rule blocks)

// Test 3: Server can write to subscriptions (via Cloud Function)
// This is tested separately via Cloud Functions
```

### Test 4: Monitoring & Observability
```bash
# Get health status
curl http://localhost:8000/api/monitoring/health
# Expected: 200 OK with service status

# Get metrics
curl -H "Authorization: Bearer YOUR_TOKEN" \
  http://localhost:8000/api/monitoring/metrics
# Expected: Latency, error rates, cache stats

# Get diagnostics
curl http://localhost:8000/api/monitoring/diagnostics
# Expected: Full system status
```

### Test 5: Subscription Access Control
```bash
# User with free plan tries to access premium feature
curl -H "Authorization: Bearer FREE_USER_TOKEN" \
  http://localhost:8000/api/advanced-features/custom-strategy
# Expected: 403 Forbidden (not in premium plan)

# User with premium plan accesses feature
curl -H "Authorization: Bearer PREMIUM_USER_TOKEN" \
  http://localhost:8000/api/advanced-features/custom-strategy
# Expected: 200 OK
```

---

## Post-Deployment Monitoring

### Critical Metrics to Monitor

**1. Error Rates**
```
Target: <1% overall error rate
Alert: >5% error rate for 5 minutes
Check: /api/monitoring/metrics -> error_rate
```

**2. Latency**
```
Target: p95 < 200ms
Alert: p95 > 500ms for 10 minutes
Check: /api/monitoring/metrics -> latency percentiles
```

**3. Authentication**
```
Target: 0% auth failures on protected endpoints
Alert: >10% 401/403 responses
Check: /api/monitoring/metrics -> by endpoint
```

**4. Rate Limiting**
```
Target: <5% 429 responses
Alert: >20% 429 responses
Check: Log aggregation -> count of 429 status codes
```

**5. Database**
```
Target: All queries < 100ms
Alert: >500ms average query time
Check: Firestore console > Usage stats
```

---

## Rollback Plan

If issues occur, rollback in this order:

### 1. Firestore Rules Rollback
```bash
# Revert to previous version
firebase firestore:rollback
# Or manually revert in console
```

### 2. Backend Rollback
```bash
# Railway: Redeploy previous build
# OR: Push previous version
git revert <commit>
git push origin main
```

### 3. Frontend Rollback  
```bash
# Vercel: Go to Deployments > Previous > Redeploy
# OR: Redeploy previous commit from console
```

---

## Success Criteria Checklist

### ✓ Frontend
- [ ] HTTPS on all requests
- [ ] No unencrypted data transmission
- [ ] Token-based auth working
- [ ] Secure headers present
- [ ] No console errors in production

### ✓ Backend  
- [ ] All protected endpoints require auth
- [ ] Rate limiting enforced (verified by testing)
- [ ] No blocking calls in async functions
- [ ] Clean modular architecture
- [ ] All Phase 6 tests passing (34/34)
- [ ] Monitoring working (/api/monitoring/*)

### ✓ Database
- [ ] Security rules deployed and enforced
- [ ] Query indexes created and active
- [ ] Data isolation working (user can't access others' data)
- [ ] Collections structured properly
- [ ] Backup configured

### ✓ Observability
- [ ] Monitoring endpoints responding
- [ ] Metrics being collected
- [ ] Health checks passing
- [ ] Alerts configured
- [ ] Logs aggregated

---

## Production Status Check

Run this command to get complete status:

```bash
#!/bin/bash

echo "================================"
echo "PHASE 7 PRODUCTION STATUS CHECK"
echo "================================"

# 1. Backend health
echo -e "\n1. BACKEND HEALTH"
curl -s http://localhost:8000/api/monitoring/health | jq '.'

# 2. Auth validation
echo -e "\n2. AUTH VALIDATION"
python Backend/app/validators/auth_validator.py 2>/dev/null | tail -5

# 3. Test protected endpoint
echo -e "\n3. PROTECTED ENDPOINT TEST"
curl -s -I http://localhost:8000/api/accounts/connections
echo "Expected: 401 Unauthorized"

# 4. Database rules
echo -e "\n4. FIRESTORE RULES STATUS"
firebase firestore:ruleset list

# 5. Indexes
echo -e "\n5. FIRESTORE INDEXES"
firebase firestore:indexes list

echo -e "\n================================"
echo "STATUS CHECK COMPLETE"
echo "================================"
```

---

## Final Deployment Commands

```bash
# 1. Deploy Firestore Rules
cd Backend
firebase deploy --only firestore:rules

# 2. Deploy Firestore Indexes
firebase deploy --only firestore:indexes

# 3. Deploy Backend (Railway - automatic via git)
git add .
git commit -m "Phase 7: Production Hardening & Final Optimization"
git push origin main
# Railway auto-deploys on push

# 4. Deploy Frontend (Vercel - automatic via git)
# Frontend auto-deploys on push to main

# 5. Verify Post-Deployment
sleep 60  # Wait for deployments
bash production_status_check.sh

# 6. Run smoke tests
pytest tests/test_phase6_observability.py -v --tb=short
```

---

## Phase 7 Complete

Once all validations pass:

✓ **Frontend**: Stateless, Secure, Token-based
✓ **Backend**: Auth-verified, Rate-limited, Async-safe, Modular  
✓ **Database**: Secure rules, Indexed, Subscription-aware
✓ **Monitoring**: Health checks, Metrics, Alerts
✓ **Testing**: 34/34 tests passing

**All 7 Phases Complete - System is Production Ready** 🚀
