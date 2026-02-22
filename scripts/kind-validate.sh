#!/usr/bin/env bash
set -euo pipefail

APP_TIMEOUT_SECONDS="${APP_TIMEOUT_SECONDS:-300}"
POD_TIMEOUT_SECONDS="${POD_TIMEOUT_SECONDS:-180}"
POLL_SECONDS=5
CLUSTER_NAME="homelab-starter"
KIND_CONTEXT="kind-${CLUSTER_NAME}"

require() {
  command -v "$1" >/dev/null 2>&1 || { echo "[ERR] missing tool: $1"; exit 1; }
}

require kubectl

k() {
  kubectl --context "${KIND_CONTEXT}" "$@"
}

wait_for_app() {
  local app="$1"
  local start now elapsed sync health
  start=$(date +%s)

  echo "[INFO] waiting for application ${app}"
  while true; do
    now=$(date +%s)
    elapsed=$((now - start))

    sync=$(k -n argocd get application "$app" -o jsonpath='{.status.sync.status}' 2>/dev/null || echo "Unknown")
    health=$(k -n argocd get application "$app" -o jsonpath='{.status.health.status}' 2>/dev/null || echo "Unknown")

    echo "[INFO] ${app} sync=${sync} health=${health} elapsed=${elapsed}s"

    if [[ "$sync" == "Synced" && "$health" == "Healthy" ]]; then
      return 0
    fi

    if [[ "$elapsed" -ge "$APP_TIMEOUT_SECONDS" ]]; then
      echo "[ERR] timeout waiting for ${app}"
      k -n argocd describe application "$app" || true
      return 1
    fi

    sleep "$POLL_SECONDS"
  done
}

wait_for_namespace_pods() {
  local ns="$1"
  local start now elapsed
  start=$(date +%s)

  echo "[INFO] waiting for pods in namespace ${ns}"
  while true; do
    now=$(date +%s)
    elapsed=$((now - start))

    # If no pods yet, keep waiting
    if [[ "$(k -n "$ns" get pods --no-headers 2>/dev/null | wc -l | tr -d ' ')" -eq 0 ]]; then
      if [[ "$elapsed" -ge "$POD_TIMEOUT_SECONDS" ]]; then
        echo "[ERR] no pods appeared in namespace ${ns}"
        k -n "$ns" get pods || true
        return 1
      fi
      sleep "$POLL_SECONDS"
      continue
    fi

    if k -n "$ns" wait --for=condition=Ready pod --all --timeout=10s >/dev/null 2>&1; then
      echo "[INFO] pods ready in ${ns}"
      return 0
    fi

    if [[ "$elapsed" -ge "$POD_TIMEOUT_SECONDS" ]]; then
      echo "[ERR] pods not ready in namespace ${ns}"
      k -n "$ns" get pods -o wide || true
      k -n "$ns" describe pods || true
      return 1
    fi

    sleep "$POLL_SECONDS"
  done
}

echo "[INFO] validating ArgoCD applications"
wait_for_app app-of-apps
wait_for_app operators-app-of-apps
wait_for_app security-app-of-apps
wait_for_app apps-app-of-apps
wait_for_app security-namespaces
wait_for_app cert-manager
wait_for_app external-secrets
wait_for_app httpbin

echo "[INFO] validating namespaces and workloads"
k get ns cert-manager external-secrets demo >/dev/null
wait_for_namespace_pods cert-manager
wait_for_namespace_pods external-secrets
wait_for_namespace_pods demo

echo "[INFO] validation summary"
k -n argocd get applications -o wide
k -n cert-manager get pods -o wide
k -n external-secrets get pods -o wide
k -n demo get pods -o wide

echo "[OK] kind profile validation passed"
