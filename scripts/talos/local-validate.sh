#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
CLUSTER_NAME="${CLUSTER_NAME:-starter-talos}"
KUBE_CONTEXT="${KUBE_CONTEXT:-${CLUSTER_NAME}}"

exec "${ROOT_DIR}/smoke/scripts/run.sh" --profile local --context "${KUBE_CONTEXT}"
