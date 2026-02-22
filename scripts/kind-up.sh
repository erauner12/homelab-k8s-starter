#!/usr/bin/env bash
set -euo pipefail

CLUSTER_NAME="homelab-starter"
KIND_CONFIG="kind/cluster-config.yaml"

require() {
  command -v "$1" >/dev/null 2>&1 || { echo "[ERR] missing tool: $1"; exit 1; }
}

require kind
require kubectl

wait_for_argocd_sync() {
  local timeout_seconds=240
  local start
  start=$(date +%s)

  echo "[INFO] waiting for app-of-apps sync and child application creation"
  while true; do
    local now elapsed sync_status health_status app_count
    now=$(date +%s)
    elapsed=$((now - start))

    sync_status=$(kubectl -n argocd get application app-of-apps -o jsonpath='{.status.sync.status}' 2>/dev/null || echo "Unknown")
    health_status=$(kubectl -n argocd get application app-of-apps -o jsonpath='{.status.health.status}' 2>/dev/null || echo "Unknown")
    app_count=$(kubectl -n argocd get applications --no-headers 2>/dev/null | wc -l | tr -d ' ')

    echo "[INFO] app-of-apps sync=${sync_status} health=${health_status} app_count=${app_count} elapsed=${elapsed}s"

    if [[ "$sync_status" == "Synced" && "$health_status" == "Healthy" && "$app_count" -ge 4 ]]; then
      break
    fi

    if [[ "$elapsed" -ge "$timeout_seconds" ]]; then
      echo "[ERR] timeout waiting for app-of-apps to reconcile"
      echo "[INFO] diagnostics:"
      kubectl -n argocd describe application app-of-apps || true
      echo "[INFO] recent repo-server logs:"
      kubectl -n argocd logs deploy/argocd-repo-server --tail=80 || true
      echo "[INFO] recent application-controller logs:"
      kubectl -n argocd logs statefulset/argocd-application-controller --tail=80 || true
      return 1
    fi

    sleep 5
  done

  echo "[INFO] waiting for expected namespaces"
  kubectl wait --for=jsonpath='{.status.phase}'=Active namespace/cert-manager --timeout=120s
  kubectl wait --for=jsonpath='{.status.phase}'=Active namespace/external-secrets --timeout=120s
  kubectl wait --for=jsonpath='{.status.phase}'=Active namespace/demo --timeout=120s
}

if ! kind get clusters | grep -q "^${CLUSTER_NAME}$"; then
  echo "[INFO] creating kind cluster ${CLUSTER_NAME}"
  kind create cluster --config "${KIND_CONFIG}"
else
  echo "[INFO] kind cluster ${CLUSTER_NAME} already exists"
fi

echo "[INFO] waiting for node readiness"
kubectl wait --for=condition=Ready nodes --all --timeout=180s

echo "[INFO] installing ArgoCD core"
kubectl create namespace argocd --dry-run=client -o yaml | kubectl apply -f -
kubectl apply --server-side -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
kubectl -n argocd rollout status deploy/argocd-server --timeout=300s
kubectl -n argocd rollout status deploy/argocd-repo-server --timeout=300s
kubectl -n argocd rollout status statefulset/argocd-application-controller --timeout=300s

echo "[INFO] applying kind bootstrap applications"
kubectl apply -k clusters/kind/bootstrap

wait_for_argocd_sync

echo "[INFO] done"
echo "[INFO] check status: ./scripts/kind-status.sh"
echo "[INFO] optional UI port-forward: kubectl -n argocd port-forward svc/argocd-server 8081:80"
