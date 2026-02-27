# Verify Railway CORS_ORIGINS Variable

The Railway UI might be showing a cached version. Let's verify what's actually saved.

## 🔍 Method 1: Clear Browser Cache and Refresh

1. **Hard Refresh Railway Dashboard:**
   - Press: `Ctrl + Shift + Delete` (Windows) to open DevTools → Clear cache
   - OR: Press `Ctrl + F5` (hard refresh) while on Railway page

2. **Go back to Railway Variables:**
   - https://railway.app → Tajir-Backend → Settings → Variables
   - Check what CORS_ORIGINS shows now

If it still shows the old value, proceed to Method 2.

---

## 🔍 Method 2: Check via Railway CLI or Logs

1. **Check Recent Deployments:**
   - Go to: https://railway.app → Tajir-Backend → Deployments
   - Look at the MOST RECENT deployment
   - Click "View Logs"
   - Search for: `CORS_ORIGINS` or `cors` 
   - What value does the log show?

2. **Or check via API call:**
   - Open browser console (F12) on Railway dashboard
   - Run this to see actual backend environment:
   ```javascript
   // Check what the backend is actually using
   fetch('https://forex-backend-production-73e7.up.railway.app/health')
     .then(r => r.headers)
     .then(headers => {
       console.log('CORS Headers:', headers.get('access-control-allow-origin'));
     })
   ```

---

## ✅ Solution: Delete and Recreate Variable

If the value is still wrong, **delete and recreate**:

1. Go to: https://railway.app → Tajir-Backend → Settings → Variables
2. Find: CORS_ORIGINS (the one showing wrong value)
3. Click: **X** (three-dot menu) → Delete
4. Wait 2 seconds
5. Click: **+ New Variable**
6. Enter:
   ```
   Variable Name: CORS_ORIGINS
   Value: https://forexcompanion-e5a28.web.app
   ```
7. Click: **Save**
8. **Refresh page** (F5) and verify it shows the correct value

---

## 🚀 After Verifying CORS_ORIGINS

Once you confirm CORS_ORIGINS is correct, **trigger a rebuild**:

```bash
cd d:\Tajir\Backend
git commit --allow-empty -m "Rebuild with correct CORS"
git push
```

Or in Railway → Deployments → Click latest deployment → Restart

---

## ✨ Expected Behavior After Fix

Once the backend redeploys with correct CORS_ORIGINS:

1. **CORS preflight from frontend will succeed** ✅
2. **Email sign-up will work** ✅
3. **No more "Access-Control-Allow-Origin" errors** ✅

---

## 🎯 Quick Checklist

- [ ] Hard refresh Railway page (Ctrl+F5)
- [ ] Check what CORS_ORIGINS variable shows
- [ ] If wrong: Delete and recreate it
- [ ] Trigger rebuild (git push or click restart)
- [ ] Wait 1-2 minutes for deployment
- [ ] Test with browser console:
  ```javascript
  fetch('https://forex-backend-production-73e7.up.railway.app/health')
    .then(r => r.json())
    .then(console.log)
  ```
