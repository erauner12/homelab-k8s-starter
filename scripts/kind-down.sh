#!/usr/bin/env bash
set -euo pipefail

CLUSTER_NAME="homelab-starter"

if kind get clusters | grep -q "^${CLUSTER_NAME}$"; then
  echo "[INFO] deleting kind cluster ${CLUSTER_NAME}"
  kind delete cluster --name "${CLUSTER_NAME}"
else
  echo "[INFO] cluster ${CLUSTER_NAME} does not exist"
fi
