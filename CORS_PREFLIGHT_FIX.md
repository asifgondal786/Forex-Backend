# CORS Preflight Fix for Email Verification

The error shows:
```
Response to preflight request doesn't pass access control check
```

This means the **OPTIONS** (preflight) request is failing with CORS headers.

---

## The Problem

When the Frontend (Firebase Hosting) tries to call Backend API:
1. Browser sends **OPTIONS** preflight request first
2. Backend should respond with CORS headers
3. If Backend returns 400 or doesn't have headers → CORS error
4. Frontend then can't send actual POST request

---

## Backend Check Required

In `Backend/app/main.py`, the FASTAPI app needs to handle OPTIONS requests properly:

```python
# This should be present in main.py:
from fastapi.middleware.cors import CORSMiddleware

app.add_middleware(
    CORSMiddleware,
    allow_origins=["https://forexcompanion-e5a28.web.app", "https://forexcompanion-e5a28.firebaseapp.com"],
    allow_credentials=True,
    allow_methods=["*"],  # This includes OPTIONS
    allow_headers=["*"],
    expose_headers=["*"],
)
```

The configuration looks correct in the code.

---

## Possible Causes

1. **Backend not restarted** - Old version running
2. **Railway environment variables not set** - Uses local .env config
3. **Backend service down** - Check Railway console
4. **Preflight request hits 400** - Something in code rejects OPTIONS

---

## Quick Test

Open browser console and try:
```javascript
fetch('https://forex-backend-production-bc44.up.railway.app/health', {
  method: 'GET',
  headers: {
    'Origin': 'https://forexcompanion-e5a28.web.app'
  }
}).then(r => r.text()).then(console.log)
```

If this works → Backend is responding to CORS properly
If this fails → Backend needs to be restarted

---

## Solution: Add Missing expose_headers

Add this line to Backend CORS config in main.py ~730:

```python
app.add_middleware(
    CORSMiddleware,
    allow_origins=_get_cors_origins(),
    allow_credentials=_cors_allow_credentials,
    allow_methods=["*"],
    allow_headers=["*"],
    expose_headers=["*"],  # ← ADD THIS LINE
    allow_origin_regex=_cors_origin_regex,
    max_age=_env_int("CORS_MAX_AGE_SECONDS", 86400),
)
```

Then redeploy Backend.

---

## Railway Auto-Deploy

1. Go to: https://railway.app
2. Select: Tajir-Backend
3. Check Deployments tab
4. Should show recent deployment
5. If no recent deploy → Backend hasn't restarted

If Backend hasn't restarted, click the restart button to pick up new CORS settings.
