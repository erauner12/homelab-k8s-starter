#!/usr/bin/env bash
set -euo pipefail

APP_TIMEOUT_SECONDS="${APP_TIMEOUT_SECONDS:-600}"
POD_TIMEOUT_SECONDS="${POD_TIMEOUT_SECONDS:-300}"
POLL_SECONDS="${POLL_SECONDS:-5}"
KUBE_CONTEXT="${KUBE_CONTEXT:-}"

require_cmd() {
  command -v "$1" >/dev/null 2>&1 || { echo "[ERR] missing tool: $1"; exit 1; }
}

k() {
  if [[ -n "${KUBE_CONTEXT}" ]]; then
    kubectl --context "${KUBE_CONTEXT}" "$@"
  else
    kubectl "$@"
  fi
}

load_yaml_list() {
  local file="$1"
  local key="$2"
  awk -v section="${key}:" '
    $0 == section { in_section=1; next }
    in_section && /^[a-z_]+:/ { in_section=0 }
    in_section && $1 == "-" { print $2 }
  ' "$file"
}

wait_for_app() {
  local app="$1"
  local start now elapsed sync health
  start="$(date +%s)"

  echo "[INFO] waiting for application ${app}"
  while true; do
    now="$(date +%s)"
    elapsed=$((now - start))

    sync="$(k -n argocd get application "$app" -o jsonpath='{.status.sync.status}' 2>/dev/null || echo "Unknown")"
    health="$(k -n argocd get application "$app" -o jsonpath='{.status.health.status}' 2>/dev/null || echo "Unknown")"

    echo "[INFO] ${app} sync=${sync} health=${health} elapsed=${elapsed}s"

    if [[ "$sync" == "Synced" && "$health" == "Healthy" ]]; then
      return 0
    fi

    if [[ "$elapsed" -ge "$APP_TIMEOUT_SECONDS" ]]; then
      echo "[ERR] timeout waiting for application ${app}"
      k -n argocd describe application "$app" || true
      return 1
    fi

    sleep "$POLL_SECONDS"
  done
}

wait_for_namespace_pods() {
  local ns="$1"
  local start now elapsed
  start="$(date +%s)"

  echo "[INFO] waiting for pods in namespace ${ns}"
  while true; do
    now="$(date +%s)"
    elapsed=$((now - start))

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

print_summary() {
  echo "[INFO] validation summary"
  k -n argocd get applications -o wide || true
  k get pods -A -o wide || true
}
