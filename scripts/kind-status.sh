#!/usr/bin/env bash
set -euo pipefail

echo "[INFO] nodes"
kubectl get nodes -o wide || true

echo ""
echo "[INFO] argocd applications"
kubectl -n argocd get applications -o wide || true

echo ""
echo "[INFO] app-of-apps details"
kubectl -n argocd get application app-of-apps -o yaml | sed -n '1,140p' || true

echo ""
echo "[INFO] key namespaces"
kubectl get ns argocd cert-manager external-secrets demo || true

echo ""
echo "[INFO] pods in key namespaces"
kubectl -n argocd get pods || true
kubectl -n cert-manager get pods || true
kubectl -n external-secrets get pods || true
kubectl -n demo get pods || true
