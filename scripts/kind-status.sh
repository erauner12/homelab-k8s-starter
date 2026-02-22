#!/usr/bin/env bash
set -euo pipefail

CLUSTER_NAME="homelab-starter"
KIND_CONTEXT="kind-${CLUSTER_NAME}"

k() {
  kubectl --context "${KIND_CONTEXT}" "$@"
}

echo "[INFO] nodes"
k get nodes -o wide || true

echo ""
echo "[INFO] argocd applications"
k -n argocd get applications -o wide || true

echo ""
echo "[INFO] app-of-apps details"
k -n argocd get application app-of-apps -o yaml | sed -n '1,140p' || true

echo ""
echo "[INFO] key namespaces"
k get ns argocd cert-manager external-secrets demo || true

echo ""
echo "[INFO] pods in key namespaces"
k -n argocd get pods || true
k -n cert-manager get pods || true
k -n external-secrets get pods || true
k -n demo get pods || true
