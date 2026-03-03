#!/usr/bin/env bash
set -euo pipefail

echo "Security Healthcheck - Forex Backend"
echo "Timestamp: $(date -u +"%Y-%m-%dT%H:%M:%SZ")"

echo
echo "1) Environment validation"
python -m app.config.validate_env --json

echo
echo "2) Secret signature scan (tracked files)"
SECRET_REGEX='AIza[0-9A-Za-z_-]{20,}|xkeysib-[A-Za-z0-9-]{20,}|BEGIN PRIVATE KEY'
if git grep -n -E "$SECRET_REGEX"; then
  echo "Potential secrets found in tracked files."
  exit 1
fi
echo "No secret signatures found in tracked files."

echo
echo "3) Recent history scan (last 200 commits)"
if git log -n 200 -p -G "$SECRET_REGEX" | grep -q '^commit '; then
  echo "Potential secret signature found in recent history window."
  exit 1
fi
echo "No secret signatures found in recent history window."

echo
echo "4) Targeted security tests"
pytest -q tests/test_env_validation.py tests/test_config_audit.py tests/test_audit_middleware.py

echo
echo "Security healthcheck complete."
