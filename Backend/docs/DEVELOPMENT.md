# Development Guide

## Local Setup

1. Create and activate a virtual environment:
```powershell
python -m venv .venv
.\.venv\Scripts\Activate.ps1
```
2. Install dependencies:
```powershell
pip install -r requirements.txt
```
3. Copy safe defaults to local overrides:
```powershell
Copy-Item .env.development .env.development.local
Copy-Item .env .env.local
```
4. Add your personal secrets only to `.env.development.local` or `.env.local`.

## Install Git Hooks

PowerShell:
```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\install-git-hooks.ps1
```

Bash:
```bash
./scripts/install-git-hooks.sh
```

## Validate Configuration

Run before starting the app:
```powershell
python -m app.config.validate_env --json
```

Use strict mode (warnings fail the command):
```powershell
python -m app.config.validate_env --strict
```

## Weekly Security Healthcheck

PowerShell:
```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\security-healthcheck.ps1
```

Bash:
```bash
./scripts/security-healthcheck.sh
```

## Run Backend

```powershell
uvicorn app.main:app --host 127.0.0.1 --port 8080 --reload
```

Or use helper:
```powershell
powershell -ExecutionPolicy Bypass -File .\run-dev.ps1
```

## Test

```powershell
pytest -q
```

## Rules

- Never place real production credentials in committed files.
- Keep personal overrides in `.env*.local` only.
- Run env validation before commit and before deploy.
- Keep `.githooks/pre-commit` active in your local repo.
- If history is rewritten, follow `HISTORY_REWRITE_NOTICE.md` to resync safely.
