# Local Development with Docker

Docker Compose standardises the local dev environment and matches production
more closely than running uvicorn directly.

## Prerequisites

- [Docker Desktop](https://www.docker.com/products/docker-desktop/) installed and running
- `Backend/.env.development` populated (copy from `Backend/.env.example`)

## Quick Start

```bash
# From the monorepo root (D:\Tajir\)

# First time or after requirements.txt changes:
docker compose up --build

# Subsequent starts:
docker compose up

# Stop:
docker compose down
```

Backend is available at **http://localhost:8080**

- API docs: http://localhost:8080/docs
- Health: http://localhost:8080/health

Hot-reload is enabled — save any `.py` file and uvicorn restarts automatically.

## Running Tests Inside Docker

```bash
docker compose exec backend pytest tests/ -v
```

## Optional: Supabase Local Emulator

Spins up a local Postgres instance on port 54322 for offline RLS testing
without touching the production database.

```bash
docker compose --profile supabase up
```

Connect with:
- Host: `localhost`
- Port: `54322`
- User: `postgres`
- Password: `postgres`
- Database: `postgres`

## Rebuilding the Image

Only needed when `requirements.txt` changes:

```bash
docker compose up --build
```

## Notes

- The container uses **Python 3.12** to match the local development environment.
  Railway's nixpacks build currently uses Python 3.11 — this is a known mismatch
  flagged for resolution in Phase 1 (Platform Consolidation).
- Source code is bind-mounted, not copied into the image, so the image only
  needs to be rebuilt when dependencies change.
- Dev auth flags (`DEBUG=true`, `ALLOW_DEV_USER_ID`) are set automatically by
  the Compose file and are hard-disabled in production by `security.py`.