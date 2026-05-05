# ============================================================
# Tajir Backend — Production Dockerfile
# Multi-stage build for minimal image size
# ============================================================
FROM python:3.11-slim AS base

# Security: non-root user
RUN groupadd -r tajir && useradd -r -g tajir -d /app -s /sbin/nologin tajir

WORKDIR /app

# System dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    gcc \
    libffi-dev \
    curl \
    && rm -rf /var/lib/apt/lists/*

# Python dependencies (cached layer)
COPY requirements.txt .
RUN pip install --no-cache-dir --upgrade pip && \
    pip install --no-cache-dir -r requirements.txt

# Application code
COPY app/ ./app/

# Own files as non-root user
RUN chown -R tajir:tajir /app
USER tajir

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=15s --retries=3 \
    CMD curl -f http://localhost:8000/health || exit 1

# Expose port
EXPOSE 8000

# Production server
CMD ["gunicorn", "app.main:app", \
     "-w", "4", \
     "-k", "uvicorn.workers.UvicornWorker", \
     "--bind", "0.0.0.0:8000", \
     "--access-logfile", "-", \
     "--error-logfile", "-", \
     "--timeout", "120", \
     "--graceful-timeout", "30"]
