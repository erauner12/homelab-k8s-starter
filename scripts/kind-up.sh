#!/usr/bin/env bash
set -euo pipefail

CLUSTER_NAME="homelab-starter"
KIND_CONFIG="kind/cluster-config.yaml"

require() {
  command -v "$1" >/dev/null 2>&1 || { echo "[ERR] missing tool: $1"; exit 1; }
}

require kind
require kubectl

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

echo "[INFO] done"
echo "[INFO] check status: ./scripts/kind-status.sh"
echo "[INFO] optional UI port-forward: kubectl -n argocd port-forward svc/argocd-server 8081:80"
