#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
TALOS_DIR="${TALOS_DIR:-${ROOT_DIR}/.talos}"
TALOS_STATE_DIR="${TALOS_STATE_DIR:-${TALOS_DIR}/clusters}"
TALOSCONFIG_PATH="${TALOSCONFIG_PATH:-${TALOS_DIR}/config}"
CLUSTER_NAME="${CLUSTER_NAME:-starter-talos}"
PROVISIONER="${PROVISIONER:-docker}"

mkdir -p "${TALOS_STATE_DIR}" "$(dirname "${TALOSCONFIG_PATH}")"
export TALOSCONFIG="${TALOSCONFIG_PATH}"

talosctl cluster destroy \
  --name "${CLUSTER_NAME}" \
  --provisioner "${PROVISIONER}" \
  --state "${TALOS_STATE_DIR}" \
  --talosconfig "${TALOSCONFIG_PATH}"
echo "[OK] destroyed Talos cluster: ${CLUSTER_NAME}"
