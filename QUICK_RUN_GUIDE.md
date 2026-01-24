# ⚡ QUICK START - Running Forex Companion Tajir

## 🚀 Start Here (Pick One Option)

### Option 1: Backend Only (Fastest - 30 seconds)
Perfect for testing the API endpoints.

```bash
# Terminal 1
cd D:\Tajir\Backend
python run.py

# Server will start on http://127.0.0.1:8000
# View API docs: http://127.0.0.1:8000/docs
```

**Test the API:**
```bash
# In another terminal or use Postman
curl http://127.0.0.1:8000/health
curl http://127.0.0.1:8000/

# Create a task
curl -X POST http://127.0.0.1:8000/api/tasks/create \
  -H "Content-Type: application/json" \
  -d '{
    "title": "Test Task",
    "description": "Testing API",
    "task_type": "market_analysis",
    "priority": "high",
    "auto_trade_enabled": false,
    "include_forecast": true
  }'
```

---

### Option 2: Backend + Frontend Full Stack
For complete end-to-end testing with real integration.

**Terminal 1 - Backend:**
```bash
cd D:\Tajir\Backend
python run.py
```

**Terminal 2 - Frontend:**
```bash
cd D:\Tajir\Frontend
flutter pub get    # First time only
flutter run        # Choose web or mobile target
```

**Then in the app:**
1. Click "Assign New Task" button
2. Fill in task details
3. Click "Start Task"
4. Watch Live Updates panel on the right show real-time progress!

---

### Option 3: Frontend Only with Mock Data
For UI development without a backend.

**Edit:** `Frontend/lib/main.dart` line 19:
```dart
const bool useMockData = true;  // Change to TRUE
```

**Then run:**
```bash
cd D:\Tajir\Frontend
flutter run
```

You'll see:
- ✅ Dashboard with mock task
- ✅ Running task with progress (3/4 steps)
- ✅ Live Updates panel showing simulated updates
- ✅ All buttons working (Stop, Pause, Refresh)

---

## 🔍 Verify Everything Works

### Check Backend Health
```bash
curl http://127.0.0.1:8000/health
```

Should return:
```json
{
  "status": "healthy",
  "ai_engine": "active",
  "connections": 0
}
```

### Check WebSocket (Python)
```python
import asyncio
import websockets

async def test():
    async with websockets.connect('ws://127.0.0.1:8000/api/ws/test-task-id') as ws:
        msg = await ws.recv()
        print(f"Received: {msg}")

asyncio.run(test())
```

---

## 📊 What You'll See

### Backend Console
```
INFO:     Uvicorn running on http://0.0.0.0:8000
INFO:     Application startup complete.
INFO:     ('127.0.0.1', 64435) - "WebSocket /api/ws/task-id" [accepted]
INFO:     127.0.0.1:65491 - "POST /api/tasks/create HTTP/1.1" 200 OK
```

### Frontend App
```
Dashboard Screen:
┌─────────────────────────────────────────────┐
│ Welcome To Forex Companion                  │
│ [+ Assign New Task]  [Help]                 │
│                                              │
│ Active Tasks           │  Live Updates       │
│ ┌────────────────────┐ │ ┌────────────────┐ │
│ │ Market Analysis    │ │ │ Live Updates   │ │
│ │ Status: Running ▶  │ │ │ 🟢 Connected   │ │
│ │ Progress: 3/4 ███▓ │ │ │ ─────────────  │ │
│ │ [Stop] [Pause]     │ │ │ ✅ AI generated│ │
│ └────────────────────┘ │ │    market      │ │
│                        │ │    summary     │ │
│                        │ └────────────────┘ │
└─────────────────────────────────────────────┘
```

---

## 🛠️ Troubleshooting

| Problem | Solution |
|---------|----------|
| "Port 8000 already in use" | Kill existing process: `netstat -ano \| findstr :8000` then `taskkill /PID <PID> /F` |
| "Module not found" | Run: `pip install PyJWT` in Backend venv |
| "WebSocket connection failed" | Ensure Backend is running on port 8000 |
| "Flutter not found" | Install from https://flutter.dev/docs/get-started/install |
| Black screen on "Assign New Task" | Pull latest code and rebuild |

---

## 📱 Available Endpoints

```
GET  /                           Root (features list)
GET  /health                     Health check
POST /api/tasks/create           Create task
GET  /api/tasks/{task_id}        Get task details
POST /api/tasks/{task_id}/stop   Stop task
POST /api/tasks/{task_id}/pause  Pause task
POST /api/tasks/{task_id}/resume Resume task
WS   /api/ws/{task_id}           Live updates
```

---

## ✨ Try This First

**Fastest way to see it working (1 minute):**

```bash
# Terminal 1
cd D:\Tajir\Backend
python run.py

# Terminal 2 (after backend starts)
cd D:\Tajir\Frontend
flutter run

# In the Flutter app that opens:
# 1. Click "Assign New Task"
# 2. Fill: Title="Market Analysis", Description="Test"
# 3. Click "Start Task"
# 4. Watch the Live Updates panel on the right show real-time progress!
```

---

## 💡 Pro Tips

1. **See API Docs:** Open http://127.0.0.1:8000/docs in browser (interactive Swagger UI)
2. **Debug Frontend:** Run Flutter with verbose logging: `flutter run -v`
3. **Monitor Backend:** Watch the terminal for WebSocket connection logs
4. **Test WebSocket:** Use Postman WebSocket tester or curl with `websocat`
5. **Reset everything:** Delete `Backend/__pycache__` and run `flutter clean`

---

**Next:** Check [PROJECT_EXECUTION_COMPLETE.md](PROJECT_EXECUTION_COMPLETE.md) for detailed information!

