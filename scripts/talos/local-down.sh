#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
TALOS_DIR="${TALOS_DIR:-${ROOT_DIR}/.talos}"
TALOS_STATE_DIR="${TALOS_STATE_DIR:-${TALOS_DIR}/clusters}"
TALOSCONFIG_PATH="${TALOSCONFIG_PATH:-${TALOS_DIR}/config}"
CLUSTER_NAME="${CLUSTER_NAME:-starter-talos}"
PROVISIONER="${PROVISIONER:-docker}"
PRUNE_STALE_E2E_CONTEXTS="${PRUNE_STALE_E2E_CONTEXTS:-true}"

mkdir -p "${TALOS_STATE_DIR}" "$(dirname "${TALOSCONFIG_PATH}")"
export TALOSCONFIG="${TALOSCONFIG_PATH}"

talosctl cluster destroy \
  --name "${CLUSTER_NAME}" \
  --provisioner "${PROVISIONER}" \
  --state "${TALOS_STATE_DIR}" \
  --talosconfig "${TALOSCONFIG_PATH}"

if [[ "${PRUNE_STALE_E2E_CONTEXTS}" == "true" ]]; then
  stale="$(kubectl config get-contexts -o name 2>/dev/null | rg "^${CLUSTER_NAME}-e2e[0-9]*$" || true)"
  if [[ -n "${stale}" ]]; then
    echo "[INFO] pruning stale kube contexts:"
    printf '%s\n' "${stale}" | sed 's/^/  - /'
    while IFS= read -r ctx; do
      [[ -z "${ctx}" ]] && continue
      kubectl config delete-context "${ctx}" >/dev/null 2>&1 || true
      kubectl config unset "users.${ctx}" >/dev/null 2>&1 || true
      kubectl config unset "clusters.${ctx}" >/dev/null 2>&1 || true
    done <<< "${stale}"
  fi
fi

echo "[OK] destroyed Talos cluster: ${CLUSTER_NAME}"
