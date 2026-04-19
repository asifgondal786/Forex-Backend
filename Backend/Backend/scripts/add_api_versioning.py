#!/usr/bin/env python3
"""
Tajir — Add /api/v1/ versioning.

Backend: wraps all /api/* routers under /api/v1 in main.py
Frontend: adds /api/v1 base path constant to api_service.dart

Run from D:\Tajir:
    python scripts/add_api_versioning.py --dry-run
    python scripts/add_api_versioning.py
"""
from __future__ import annotations
import argparse
import sys
from pathlib import Path

ROOT = Path(".")
BACKEND_MAIN = ROOT / "Backend/app/main.py"
FRONTEND_SERVICE = ROOT / "Frontend/lib/services/api_service.dart"


# ── Backend patch ─────────────────────────────────────────────────────────────
# Strategy: add a versioned APIRouter and mount all existing /api routers
# under it. Unversioned routes (/health, /healthz, /api/health, /auth) untouched.

BACKEND_IMPORT_OLD = "from .services.rate_limiter import RateLimiter"
BACKEND_IMPORT_NEW = """from .services.rate_limiter import RateLimiter
from fastapi.routing import APIRouter as _APIRouter"""

# The include_router block — wrap in v1 router
ROUTER_BLOCK_OLD = """# Include routers
app.include_router(users_router)
app.include_router(websocket_router)
app.include_router(engagement_router)
app.include_router(auth_status_router)
app.include_router(header_router)
app.include_router(notifications_router)
app.include_router(settings_router)
if AI_ROUTES_AVAILABLE:
    app.include_router(ai_task_router)
if ADVANCED_FEATURES_AVAILABLE:
    app.include_router(advanced_router)
if ACCOUNTS_ROUTES_AVAILABLE:
    app.include_router(accounts_router)
if SUBSCRIPTION_ROUTES_AVAILABLE:
    app.include_router(subscription_router)
if CREDENTIAL_VAULT_ROUTES_AVAILABLE:
    app.include_router(credential_vault_router)
if PUBLIC_AUTH_ROUTES_AVAILABLE:
    app.include_router(public_auth_router)
if OPS_ROUTES_AVAILABLE:
    app.include_router(ops_router)
if MONITORING_ROUTES_AVAILABLE:
    app.include_router(monitoring_router)
if AI_PROXY_AVAILABLE:
    app.include_router(ai_proxy_router)"""

ROUTER_BLOCK_NEW = """# ── API v1 versioned router ──────────────────────────────────────────────────
# All /api/* routes are mounted under /api/v1 via this wrapper.
# Unversioned routes (/health, /healthz, /api/health, /auth) are registered
# directly on `app` below and remain unaffected.
_v1 = _APIRouter(prefix="/v1")

_v1.include_router(users_router)
_v1.include_router(websocket_router)
_v1.include_router(engagement_router)
_v1.include_router(auth_status_router)
_v1.include_router(header_router)
_v1.include_router(notifications_router)
_v1.include_router(settings_router)
if AI_ROUTES_AVAILABLE:
    _v1.include_router(ai_task_router)
if ADVANCED_FEATURES_AVAILABLE:
    _v1.include_router(advanced_router)
if ACCOUNTS_ROUTES_AVAILABLE:
    _v1.include_router(accounts_router)
if SUBSCRIPTION_ROUTES_AVAILABLE:
    _v1.include_router(subscription_router)
if CREDENTIAL_VAULT_ROUTES_AVAILABLE:
    _v1.include_router(credential_vault_router)
if OPS_ROUTES_AVAILABLE:
    _v1.include_router(ops_router)
if MONITORING_ROUTES_AVAILABLE:
    _v1.include_router(monitoring_router)
if AI_PROXY_AVAILABLE:
    _v1.include_router(ai_proxy_router)

# Mount v1 router — all /api/* routes become /api/v1/*
app.include_router(_v1)

# Unversioned routes (public auth, no /api prefix)
if PUBLIC_AUTH_ROUTES_AVAILABLE:
    app.include_router(public_auth_router)"""


# ── Frontend patch ────────────────────────────────────────────────────────────
# The Flutter app uses $baseUrl/api/... everywhere.
# Adding /v1 to baseUrl would require touching every single call.
# Better: add a versioned getter _apiV1 and a note, but the cleanest
# zero-risk approach is to add the /v1 segment inside _normalizeBaseUrl
# so ALL existing calls get it automatically.
#
# We add a static const apiPath = '/api/v1' and update the two hardcoded
# /api/ path prefixes by replacing '/api/' with '/api/v1/' in the Uri.parse calls.

FLUTTER_OLD = "  static const String _baseUrlFromDefine = String.fromEnvironment("
FLUTTER_NEW = """  /// API version prefix — all versioned endpoints use this path segment.
  static const String apiV1 = '/api/v1';

  static const String _baseUrlFromDefine = String.fromEnvironment("""


def patch_backend(text: str, dry_run: bool) -> tuple[str, list[str]]:
    changes = []
    original = text

    if "from fastapi.routing import APIRouter as _APIRouter" not in text:
        if BACKEND_IMPORT_OLD in text:
            text = text.replace(BACKEND_IMPORT_OLD, BACKEND_IMPORT_NEW, 1)
            changes.append("  ✅ Added _APIRouter import")
        else:
            changes.append("  ⏭️  SKIP import (not found — already patched?)")

    if "_v1 = _APIRouter(prefix=" not in text:
        if ROUTER_BLOCK_OLD in text:
            text = text.replace(ROUTER_BLOCK_OLD, ROUTER_BLOCK_NEW, 1)
            changes.append("  ✅ Wrapped all /api routers under /api/v1")
        else:
            changes.append("  ⏭️  SKIP router block (not found — check manually)")
    else:
        changes.append("  ⏭️  Backend already versioned")

    return text, changes


def patch_frontend(text: str, dry_run: bool) -> tuple[str, list[str]]:
    changes = []

    if "static const String apiV1" not in text:
        if FLUTTER_OLD in text:
            text = text.replace(FLUTTER_OLD, FLUTTER_NEW, 1)
            changes.append("  ✅ Added apiV1 constant to ApiService")
        else:
            changes.append("  ⏭️  SKIP apiV1 constant (insertion point not found)")
    else:
        changes.append("  ⏭️  apiV1 constant already present")

    # Replace /api/ → /api/v1/ in all Uri.parse calls
    # but NOT /api/health or /api/ws (unversioned)
    import re
    pattern = re.compile(r"(\\\$baseUrl/api/)(?!health|ws|v1)")
    new_text, count = pattern.subn(r"$baseUrl/api/v1/", text)
    if count > 0:
        text = new_text
        changes.append(f"  ✅ Updated {count} Uri.parse paths: /api/ → /api/v1/")
    else:
        changes.append("  ⏭️  No /api/ paths to update (already done or pattern mismatch)")

    return text, changes


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--dry-run", action="store_true")
    args = parser.parse_args()

    mode = "DRY RUN" if args.dry_run else "LIVE"
    print(f"\n{'='*60}")
    print(f"  Tajir API Versioning  [{mode}]")
    print(f"{'='*60}\n")

    if not BACKEND_MAIN.exists():
        print(f"ERROR: {BACKEND_MAIN} not found. Run from D:\\Tajir")
        sys.exit(1)

    # Backend
    print(f"📄 {BACKEND_MAIN}")
    text = BACKEND_MAIN.read_text(encoding="utf-8")
    new_text, changes = patch_backend(text, args.dry_run)
    for c in changes:
        print(c)
    if new_text != text and not args.dry_run:
        BACKEND_MAIN.write_text(new_text, encoding="utf-8")
    print()

    # Frontend
    print(f"📄 {FRONTEND_SERVICE}")
    text = FRONTEND_SERVICE.read_text(encoding="utf-8")
    new_text, changes = patch_frontend(text, args.dry_run)
    for c in changes:
        print(c)
    if new_text != text and not args.dry_run:
        FRONTEND_SERVICE.write_text(new_text, encoding="utf-8")
    print()

    print(f"{'='*60}")
    if args.dry_run:
        print("  DRY RUN complete. Run without --dry-run to apply.\n")
    else:
        print("  Done. Next steps:")
        print("  1. cd Backend && git add app/main.py && git commit -m 'feat: /api/v1 versioning' && git push")
        print("  2. cd Frontend && flutter analyze && git add lib/services/api_service.dart && git commit -m 'feat: update API calls to /api/v1' && git push")
        print("  3. Verify: curl https://forex-backend-production-bc44.up.railway.app/api/v1/health-check\n")


if __name__ == "__main__":
    main()