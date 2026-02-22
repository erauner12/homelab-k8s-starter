#!/usr/bin/env bash
set -euo pipefail

KUBE_CONTEXT="${KUBE_CONTEXT:-}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

source "${REPO_ROOT}/scripts/lib/kube-common.sh"
kube_common_init "openclaw/scripts/approve-latest-pairing.sh"

NAMESPACE="${OPENCLAW_NAMESPACE:-ai}"
DEPLOYMENT="${OPENCLAW_DEPLOYMENT:-openclaw}"

if ! "${KUBECTL_CMD[@]}" -n "$NAMESPACE" exec "deploy/${DEPLOYMENT}" -- sh -lc '
  openclaw devices approve --latest 2>/dev/null || \
  node /app/openclaw.mjs devices approve --latest 2>/dev/null
'; then
  echo "No pending pairing request to approve (or request already handled)."
fi

echo ""
echo "Paired devices status:"
"${KUBECTL_CMD[@]}" -n "$NAMESPACE" exec "deploy/${DEPLOYMENT}" -- sh -lc '
  openclaw devices list 2>/dev/null || \
  node /app/openclaw.mjs devices list 2>/dev/null
'
