#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
TALOS_DIR="${TALOS_DIR:-${ROOT_DIR}/.talos}"
TALOS_STATE_DIR="${TALOS_STATE_DIR:-${TALOS_DIR}/clusters}"
TALOSCONFIG_PATH="${TALOSCONFIG_PATH:-${TALOS_DIR}/config}"

run_with_timeout() {
  local seconds="$1"
  shift
  if command -v gtimeout >/dev/null 2>&1; then
    gtimeout "$seconds" "$@" || true
  else
    "$@" || true
  fi
}

echo "Talos local clusters:"
if command -v talosctl >/dev/null 2>&1; then
  TALOSCONFIG="${TALOSCONFIG_PATH}" run_with_timeout 10 talosctl cluster show --state "${TALOS_STATE_DIR}" 2>/dev/null
fi

echo ""
echo "Kubernetes contexts containing 'talos' or 'starter':"
kubectl config get-contexts -o name | rg "talos|starter" || true

echo ""
echo "Current nodes (if context set):"
run_with_timeout 10 kubectl get nodes -o wide 2>/dev/null
