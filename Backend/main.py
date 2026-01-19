"""
Deprecated entrypoint.
Use Backend/app/main.py as the single source of truth.
"""

import os
from fastapi import FastAPI
from app.main import app as _app

app: FastAPI = _app


if __name__ == "__main__":
    import uvicorn

    print("WARNING: Backend/main.py is deprecated. Use `uvicorn app.main:app`.")
    port = int(os.getenv("PORT", 8080))
    uvicorn.run(
        "app.main:app",
        host="0.0.0.0",
        port=port,
        reload=True,
        log_level="info",
    )