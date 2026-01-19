# ⚡ Quick Command Reference

## 🚀 START HERE - Run These Commands

### Terminal 1: Start Backend
```bash
cd d:\Tajir\Backend
python -m uvicorn app.main:app --reload --port 8000
```

**Expected Output:**
```
========================
🎯 Forex Companion AI Backend Starting...
========================
🔗 WebSocket: ws://localhost:8000/api/ws/{task_id}
📚 API Docs: http://localhost:8000/docs
🤖 AI Engine: ACTIVE
========================
INFO:     Uvicorn running on http://127.0.0.1:8000
```

### Terminal 2: Start Frontend
```bash
cd d:\Tajir\Frontend
flutter run
```

**Expected Output:**
```
Flutter app launches on your device/emulator
Dashboard screen appears
No error messages
```

### Terminal 3: Test API (Optional)
```bash
# Test health check
curl http://127.0.0.1:8000/health

# Test task creation
curl -X POST http://127.0.0.1:8000/api/tasks/create \
  -H "Content-Type: application/json" \
  -d '{
    "title": "Test Task",
    "description": "Testing the fix",
    "priority": "high",
    "task_type": "market_analysis"
  }'
```

---

## 📋 Testing Checklist

### Pre-Flight Check (Do This First)
- [ ] Backend starts without errors
- [ ] Frontend loads without errors
- [ ] Dashboard screen visible
- [ ] "Assign New Task" button visible

### Feature Testing

**Test 1: Task Creation Form**
```
1. Click "Assign New Task" button
2. Expected: Form appears with fields (NOT black screen)
3. Actual: ________________
4. Pass: [ ] Yes [ ] No
```

**Test 2: Form Submission**
```
1. Fill in task details
2. Click "Start Task"
3. Expected: No errors, task created
4. Actual: ________________
5. Pass: [ ] Yes [ ] No
```

**Test 3: Dashboard Update**
```
1. After task creation
2. Expected: New task appears in active list
3. Actual: ________________
4. Pass: [ ] Yes [ ] No
```

**Test 4: Live Updates Panel**
```
1. After task creation
2. Expected: Live Updates panel appears on right
3. Actual: ________________
4. Pass: [ ] Yes [ ] No
```

**Test 5: WebSocket Connection**
```
1. Check Live Updates panel
2. Expected: Status shows "Connected"
3. Actual: ________________
4. Pass: [ ] Yes [ ] No
```

**Test 6: Real-time Updates**
```
1. Monitor Live Updates panel
2. Expected: Messages appear as task progresses
3. Actual: ________________
4. Pass: [ ] Yes [ ] No
```

### Final Result
```
Total Tests: 6
Passed: __ / 6
Failed: __ / 6
Status: [ ] Complete Success [ ] Some Issues [ ] Critical Problems
```

---

## 🔍 Debugging Commands

### If Black Screen on Task Creation
```bash
# Check if import is correct
grep -n "TaskCreationScreen" d:\Tajir\Frontend\lib\routes\app_routes.dart

# Rebuild
cd d:\Tajir\Frontend
flutter clean
flutter pub get
flutter run
```

### If Task Creation Fails
```bash
# Test endpoint directly
curl -X POST http://127.0.0.1:8000/api/tasks/create \
  -H "Content-Type: application/json" \
  -d '{"title":"Test","description":"Test","priority":"high","task_type":"market_analysis"}'

# Check response status
# Expected: 200 OK
# Check response has camelCase fields (createdAt, startTime, etc.)
```

### If Live Updates Not Connecting
```bash
# Check backend is running
curl http://127.0.0.1:8000/health

# Check WebSocket endpoint exists
curl http://127.0.0.1:8000/docs

# Check DevTools console for errors
# Expected: "Connecting to: ws://127.0.0.1:8000/api/ws/..."
```

### If WebSocket Timeout
```bash
# Check port 8000 is open
netstat -an | findstr :8000

# Kill any existing process on 8000
taskkill /f /im python.exe  # WARNING: Kills all Python processes

# Restart backend
python -m uvicorn app.main:app --reload --port 8000
```

---

## 📊 Verification Commands

### 1. Check Backend Health
```bash
curl http://127.0.0.1:8000/health
# Expected: {"status": "healthy", "ai_engine": "active", "connections": 0}
```

### 2. Check API Documentation
```bash
curl http://127.0.0.1:8000/docs
# Browser: http://127.0.0.1:8000/docs
```

### 3. List Active Connections
```bash
curl http://127.0.0.1:8000/api/updates/connections
# Expected: {"total_connections": 0, "tasks": []}
```

### 4. Test Frontend API
```bash
curl http://127.0.0.1:8080
# Should fail with connection refused (frontend isn't serving HTTP)
# This is normal - frontend is a Flutter app, not a web server
```

---

## 🐛 Common Issues & Fixes

### Issue: "Connection refused"
```bash
# Solution: Backend not running
# Run: python -m uvicorn app.main:app --reload --port 8000
```

### Issue: "404 Not Found"
```bash
# Solution: Wrong endpoint
# Check: API endpoint is /api/tasks/create (not /api/tasks/)
# Test: curl -X POST http://127.0.0.1:8000/api/tasks/create
```

### Issue: "WebSocket connection timeout"
```bash
# Solution: Wrong port
# Check: WebSocket URL has port 8000
# Check: live_update_service.dart line 36
```

### Issue: "Black screen when clicking button"
```bash
# Solution: Route not updated
# Check: app_routes.dart has import for TaskCreationScreen
# Check: /create-task route uses TaskCreationScreen()
# Fix: flutter clean && flutter pub get && flutter run
```

### Issue: "JSON parse error"
```bash
# Solution: Field name mismatch
# Check: Response has camelCase fields (createdAt, not created_at)
# Test: curl /api/tasks/create and check response
```

---

## 📈 Performance Monitoring

### Check Backend Performance
```bash
# Memory usage
ps aux | grep python

# Active connections
curl http://127.0.0.1:8000/api/updates/connections

# Response time
time curl http://127.0.0.1:8000/health
```

### Check Frontend Performance
- Open DevTools: Press F12
- Check: Console tab for errors
- Check: Network tab for failed requests
- Check: Performance tab for rendering time

---

## 🔄 Reset/Clean Commands

### Reset Frontend
```bash
cd d:\Tajir\Frontend
flutter clean
flutter pub get
flutter run
```

### Reset Backend
```bash
cd d:\Tajir\Backend
pip install -r requirements.txt
python -m uvicorn app.main:app --reload --port 8000
```

### Reset Everything
```bash
# Terminal 1
cd d:\Tajir\Backend && python -m uvicorn app.main:app --reload --port 8000

# Terminal 2
cd d:\Tajir\Frontend && flutter clean && flutter pub get && flutter run
```

---

## 📝 Quick Reference Table

| Command | Purpose | Success Indicator |
|---------|---------|-------------------|
| `flutter run` | Start frontend | App launches, no errors |
| `curl http://127.0.0.1:8000/health` | Check backend | `{"status": "healthy"}` |
| `curl http://127.0.0.1:8000/api/tasks/create` | Create task | 200 OK with camelCase fields |
| `flutter clean` | Reset frontend | No errors, clean start |
| `pip install -r requirements.txt` | Install dependencies | No errors |

---

## 🎯 Success Checklist

```
Backend Ready:
  [ ] python -m uvicorn command runs
  [ ] No startup errors
  [ ] curl http://127.0.0.1:8000/health returns 200
  [ ] WebSocket endpoint exists at /api/ws/{task_id}

Frontend Ready:
  [ ] flutter run completes
  [ ] App loads without errors
  [ ] Dashboard appears
  [ ] "Assign New Task" button visible

Integration Ready:
  [ ] Click button opens form (not black screen)
  [ ] Form submission succeeds
  [ ] Task appears in dashboard
  [ ] Live Updates panel appears
  [ ] "Connected" status shows

All Systems Go:
  [ ] Real-time updates appear
  [ ] Progress tracking works
  [ ] No errors in console
  [ ] Everything runs smoothly
```

---

## 📞 Getting Help

### If Something Isn't Working

1. **Check:** Terminal outputs for error messages
2. **Check:** DevTools console for frontend errors
3. **Check:** Backend terminal for API errors
4. **Test:** Run individual commands from above
5. **Reset:** Run reset commands and try again
6. **Read:** Check COMPLETE_FIX_DOCUMENTATION.md for details

### Useful Files

- Backend logs: Backend terminal output
- Frontend logs: DevTools console (F12)
- Documentation: d:\Tajir\FINAL_REPORT.md
- Quick guide: d:\Tajir\QUICK_START_GUIDE.md

---

## ✨ Quick Status Check

Run this to verify everything:

```bash
# Terminal 1: Backend running?
curl http://127.0.0.1:8000/health

# Terminal 2: API working?
curl -X POST http://127.0.0.1:8000/api/tasks/create \
  -H "Content-Type: application/json" \
  -d '{"title":"Test","description":"Test","priority":"high","task_type":"market_analysis"}'

# Expected both to return 200 OK
# If both work: Everything is configured correctly ✅
```

---

## 🎉 You're Ready!

All commands above will help you:
- Start the application
- Test the features
- Debug issues
- Verify everything works
- Monitor performance

**Go ahead and run the Quick Start commands!** 🚀

