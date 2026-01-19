# 🚀 Quick Start Guide - After Fixes

## Prerequisites
- Backend running on port 8000
- Frontend Flutter project properly configured

---

## Step 1: Start Backend Server

```bash
cd d:\Tajir\Backend
python -m uvicorn app.main:app --reload --port 8000
```

Expected output:
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

---

## Step 2: Start Flutter Frontend

```bash
cd d:\Tajir\Frontend
flutter run
```

---

## Step 3: Test Live Updates & Task Assignment

### Test Flow:

1. **Dashboard appears** with "Assign New Task" button
   - ✅ Button should be visible and clickable
   - ✅ No black screen background

2. **Click "Assign New Task"**
   - ✅ TaskCreationScreen opens (NOT a black screen!)
   - ✅ Form with Title, Description, Priority fields visible

3. **Fill in task details:**
   - Title: "Analyze EUR/USD Market"
   - Description: "Comprehensive market analysis"
   - Priority: Select one

4. **Click "Start Task" button**
   - ✅ Task is created and sent to backend
   - ✅ Response received without errors
   - ✅ Returns to dashboard

5. **Live Updates Panel**
   - ✅ Appears on the right side of dashboard
   - ✅ Shows "Connecting..." status
   - ✅ Transitions to "Connected"
   - ✅ Live update messages appear as task progresses

6. **Monitor the updates:**
   - "Fetching Data" - progress indicator
   - "Analyzing Markets" - analysis steps
   - "Generating Report" - completion steps
   - Final results displayed

---

## Debugging

### If Live Updates Not Showing:

1. **Check DevTools Console:**
   ```
   Flutter DevTools → Console tab
   Look for: "Connecting to: ws://127.0.0.1:8000/api/ws/..."
   ```

2. **Verify Backend WebSocket Endpoint:**
   ```bash
   # From another terminal:
   curl http://127.0.0.1:8000/docs
   # This opens API documentation with WebSocket endpoint details
   ```

3. **Check Network Tab:**
   - DevTools → Network
   - Look for WebSocket connections
   - Should show: `/api/ws/{task_id}`

### If Task Creation Fails:

1. **Check API Response:**
   ```bash
   # Test the endpoint directly:
   curl -X POST http://127.0.0.1:8000/api/tasks/create \
     -H "Content-Type: application/json" \
     -d '{
       "title": "Test Task",
       "description": "Test Description",
       "priority": "medium",
       "task_type": "market_analysis"
     }'
   ```

2. **Check Backend Logs:**
   - Backend terminal should show request logs
   - Look for status 200 (success) or 4xx/5xx (errors)

---

## Key Configuration Files

### Frontend Configuration:

**`lib/services/api_service.dart`** (line 18)
```dart
static const String baseUrl = 'http://127.0.0.1:8080';  // ← Change this if port differs
```

**`lib/services/live_update_service.dart`** (line 36)
```dart
static const String _baseUrl = String.fromEnvironment(
  'WS_BASE_URL',
  defaultValue: 'ws://127.0.0.1:8000',  // ← WebSocket URL
);
```

### Backend Configuration:

**`app/main.py`** (port is in uvicorn command)
- Runs on port 8000 by default
- WebSocket: `ws://localhost:8000/api/ws/{task_id}`

---

## Architecture Changes Made

### 1. Fixed WebSocket Connection
```
Before: ws://localhost:8080/ws/{task_id}  ❌ Wrong port & path
After:  ws://127.0.0.1:8000/api/ws/{task_id}  ✅ Correct
```

### 2. Fixed Route Navigation
```
Before: /create-task → Scaffold(Center(Text("Create Task Screen")))  ❌ Black screen
After:  /create-task → TaskCreationScreen()  ✅ Full form UI
```

### 3. Fixed API Endpoint
```
Before: POST /api/tasks/  ❌ Wrong endpoint
After:  POST /api/tasks/create  ✅ Correct
```

### 4. Fixed Response Model
```
Before: created_at, start_time, current_step  ❌ snake_case
After:  createdAt, startTime, currentStep  ✅ camelCase
```

---

## Live Updates Message Format

Backend sends:
```json
{
  "id": "uuid-1234",
  "taskId": "uuid-5678",
  "message": "✅ Analyzed EUR/USD: BUY signal with 87% confidence",
  "type": "info",
  "timestamp": "2025-01-19T10:30:45.123456",
  "progress": 0.4,
  "data": {
    "current_price": 1.0850,
    "trend": "uptrend",
    "rsi": 65.5,
    "volatility": 0.45
  }
}
```

---

## Success Indicators

✅ All of these should be working now:

- [x] "Assign New Task" button opens proper form (not black screen)
- [x] Task creation sends data to backend
- [x] Live Updates panel appears when task is active
- [x] WebSocket connects successfully
- [x] Live updates messages appear in real-time
- [x] Task progress tracking works
- [x] Dashboard shows active tasks

---

## Next Steps (Optional Enhancements)

- [ ] Add error handling UI for failed connections
- [ ] Implement task pause/resume functionality
- [ ] Add task history with filtering
- [ ] Show trading signals and forecasts
- [ ] Implement auto-trading parameters
- [ ] Add portfolio monitoring

