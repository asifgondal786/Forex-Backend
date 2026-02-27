# Railway Healthcheck Failure - Root Cause & Solution

## 🔴 Problem Identified

**Error:** `Deployment failed during network process > Healthcheck failure`

**Why:** 
1. App builds successfully ✅
2. App starts deploying ✅  
3. App crashes on startup ❌ **← HERE**
4. Railway healthcheck endpoint `/health` never responds
5. Railway marks deployment as FAILED

**Root Cause:**
```python
# In Backend/app/main.py lifespan() at startup:
if os.getenv("REQUIRE_FIREBASE", "").lower() == "true":
    raise RuntimeError("Firebase configuration required but not found.")
```

Your Railway Variables have `REQUIRE_FIREBASE=true` but Firebase credentials aren't being properly detected, causing the app to **crash on startup**.

---

## ✅ Solution: Temporary Workaround

### Step 1: Disable Firebase Requirement Temporarily

Go to Railway Dashboard:
1. **Tajir-Backend** → **Variables** tab
2. Find: `REQUIRE_FIREBASE`
3. Change value from: `true`
4. Change to: `false`
5. Click **Save**

This allows the app to start without Firebase, so we can debug the credentials issue.

### Step 2: Trigger Rebuild

```bash
cd d:\Tajir\Backend
git commit --allow-empty -m "Disable Firebase requirement to debug credentials"
git push
```

Or manually restart in Railway Dashboard:
- **Deployments** → Click latest → **Restart**

**Expected:** Deployment succeeds ✅

---

## 🔧 Permanent Solution: Fix Firebase Credentials

Once the app deploys successfully with `REQUIRE_FIREBASE=false`, we need to properly configure Firebase credentials.

### Option A: Use Base64 Method (Recommended)

1. **Get your Firebase service account JSON:**
   - Download from: https://console.firebase.google.com/project/forexcompanion-e5a28/settings/serviceaccounts/adminsdk

2. **Encode to Base64:**
   ```bash
   # PowerShell:
   $json = Get-Content "path\to\forexcompanion-e5a28-d2d312c6a1af.json" -Raw
   [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes($json))
   ```

3. **Update Railway Variables:**
   - Variable Name: `FIREBASE_SERVICE_ACCOUNT_JSON_B64`
   - Value: (paste the base64 string without line breaks)
   - Click **Save**

4. **Test with debug mode first:**
   - Ensure `REQUIRE_FIREBASE=false` still
   - Trigger redeploy
   - App should detect credentials as `json_b64`

---

### Option B: Use JSON String Method

If base64 doesn't work:

1. **Get your Firebase service account JSON (as before)**

2. **Minify the JSON** (remove all newlines/spaces):
   ```json
   {"type":"service_account","project_id":"forexcompanion-e5a28",...}
   ```

3. **Update Railway Variables:**
   - Variable Name: `FIREBASE_SERVICE_ACCOUNT_JSON`
   - Value: (paste minified JSON as single line)
   - Click **Save**

4. **Redeploy and test**

---

### Option C: Use Google Application Default Credentials (ADC)

```bash
# In Railway Variables, set:
GOOGLE_APPLICATION_CREDENTIALS=/var/run/secrets/firebase-key.json

# Then add your JSON as:
FIREBASE_SERVICE_ACCOUNT_JSON_B64=<base64-encoded-json>
```

---

## 🧪 Testing After Credentials Fix

Once credentials are confirmed working:

### 1. Keep `REQUIRE_FIREBASE=false` and Verify Startup

```bash
# Redeploy and watch logs
# Should see: "[Firebase] Initialized via json_b64 (project_id=forexcompanion-e5a28)"
```

### 2. Once Confirmed, Enable Firebase Requirement

1. Go to Railway Variables
2. Change: `REQUIRE_FIREBASE=true`
3. Save and redeploy
4. App should still start with message: `[Firebase] Initialized via json_b64`
5. Healthcheck should PASS ✅

---

## 📋 Checklist

- [ ] Step 1: Set `REQUIRE_FIREBASE=false` in Railway Variables
- [ ] Step 2: Trigger rebuild (empty commit or manual restart)
- [ ] Step 3: Wait for deployment to succeed
- [ ] Step 4: Check deployment logs show `Deployment successful`
- [ ] Step 5: Test `/health` endpoint: `curl https://forex-backend-production-73e7.up.railway.app/health`
- [ ] Step 6: If working, implement proper Firebase credentials (Option A or B)
- [ ] Step 7: Set `REQUIRE_FIREBASE=true` and redeploy
- [ ] Step 8: Verify Firebase logs: `[Firebase] Initialized via json_b64`

---

## 🆘 Debug Commands

If deployment still fails:

1. **View Railway logs:**
   ```
   https://railway.app → Tajir-Backend → Deployments → Latest → View logs
   ```
   Look for: `"[Firebase] Startup check failed:"`

2. **Test health locally:**
   ```bash
   # In Backend directory:
   python main.py
   # Then: curl http://localhost:8000/health
   ```

3. **Check environment variables:**
   ```bash
   # In Railway, click "Variables" tab and verify all vars are set correctly
   ```

---

## 🎯 Why This Happens

- Railway passes large environment variables as **single-line strings**
- If JSON has newlines, it becomes an invalid JSON string
- App tries to parse invalid JSON → raises exception
- With `REQUIRE_FIREBASE=true` → app crashes
- With `REQUIRE_FIREBASE=false` → app ignores Firebase and starts anyway

**This is why we fix credentials first, then enable `REQUIRE_FIREBASE=true` once verified working.**

---

**Next Step:** Set `REQUIRE_FIREBASE=false` in Railway and push an empty commit to trigger rebuild. Let me know if deployment succeeds! 🚀
