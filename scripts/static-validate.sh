#!/usr/bin/env bash
set -euo pipefail

if helm version -c --short >/dev/null 2>&1; then
  exec ./scripts/static-validate-full.sh
fi

echo "[WARN] Helm 3 not detected; running fast static validation"
echo "[WARN] run ./scripts/static-validate-full.sh with Helm 3 for complete coverage"
exec ./scripts/static-validate-fast.sh
