#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OUT_DIR="${1:-${ROOT_DIR}/talos/generated}"
CLUSTER_NAME="${CLUSTER_NAME:-starter-home}"
ENDPOINT="${ENDPOINT:-https://192.168.1.193:6443}"
KUBERNETES_VERSION="${KUBERNETES_VERSION:-1.31.5}"
INSTALL_DISK="${INSTALL_DISK:-/dev/sda}"
ENABLE_LONGHORN="${ENABLE_LONGHORN:-true}"

mkdir -p "$OUT_DIR"

echo "Generating Talos configs..."
echo "  cluster:  $CLUSTER_NAME"
echo "  endpoint: $ENDPOINT"
echo "  output:   $OUT_DIR"
echo "  longhorn: $ENABLE_LONGHORN"

args=(
  --kubernetes-version "$KUBERNETES_VERSION"
  --install-disk "$INSTALL_DISK"
  --config-patch "@${ROOT_DIR}/talos/patches/cluster-base.yaml"
  --config-patch-control-plane "@${ROOT_DIR}/talos/patches/controlplane-base.yaml"
  --config-patch-control-plane "@${ROOT_DIR}/talos/patches/machine-kubelet.yaml"
  --config-patch-control-plane "@${ROOT_DIR}/talos/patches/machine-hostdns.yaml"
  --config-patch-worker "@${ROOT_DIR}/talos/patches/worker-base.yaml"
  --config-patch-worker "@${ROOT_DIR}/talos/patches/machine-kubelet.yaml"
  --config-patch-worker "@${ROOT_DIR}/talos/patches/machine-hostdns.yaml"
)

if [[ "$ENABLE_LONGHORN" == "true" ]]; then
  args+=(--config-patch "@${ROOT_DIR}/talos/patches/longhorn-install.yaml")
fi

talosctl gen config "$CLUSTER_NAME" "$ENDPOINT" \
  "${args[@]}" \
  -o "$OUT_DIR" \
  -f

echo "Generated:"
ls -1 "$OUT_DIR"
