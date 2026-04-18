#!/usr/bin/env bash
set -euo pipefail

echo "Configuring repository git hooks path (.githooks)..."
git config core.hooksPath .githooks
echo "Done. Hooks will run from .githooks/."
