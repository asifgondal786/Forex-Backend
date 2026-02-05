# ML Live Update Backend

Real-time machine learning backend with WebSocket-based live progress updates.

## Quick Start

1. **Setup virtual environment:**
```bash
   python -m venv .venv
   .venv\Scripts\activate  # Windows
   # source .venv/bin/activate  # Linux/Mac
```

2. **Install dependencies:**
```bash
   pip install -r requirements.txt
```

3. **Run server:**
```bash
   python run.py
   # or: uvicorn app.main:app --reload --port 8080
```

4. **Access API docs:**
   - Swagger UI: http://localhost:8080/docs
   - ReDoc: http://localhost:8080/redoc

## Email/SMTP Configuration (Safe Setup)

Do **not** hardcode credentials in code or chat.

Set environment variables in your shell before running:
```powershell
$env:SMTP_HOST = "smtp.gmail.com"
$env:SMTP_PORT = "587"
$env:SMTP_USER = "your_email@gmail.com"
$env:SMTP_PASS = "your_app_password"
$env:SMTP_FROM = "your_email@gmail.com"
$env:SMTP_TLS = "true"
```

Then start the server as usual:
```bash
python run.py
```

## API Endpoints

- `POST /api/train` - Start training
- `POST /api/predict/{task_id}` - Make predictions
- `GET /api/tasks/{task_id}/status` - Check status
- `WS /api/ws/{task_id}` - Live updates WebSocket

## Project Structure

See file tree above for complete structure.
