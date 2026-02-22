#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/lib/kube-common.sh
source "${SCRIPT_DIR}/lib/kube-common.sh"

usage() {
  cat <<'USAGE'
Usage:
  scripts/argocd-ui.sh [--context <kubectl-context>] [--kubeconfig <path>] [--namespace <ns>] [--port <local-port>] [--no-open]

Defaults:
  --context    current kubectl context (or KUBE_CONTEXT env)
  --kubeconfig respects KUBECONFIG if set
  --namespace  argocd
  --port       8081

Examples:
  scripts/argocd-ui.sh --context starter-talos-e2e10
  scripts/argocd-ui.sh --kubeconfig terraform/rackspace-spot/kubeconfig-starter-cloud.yaml
USAGE
}

KUBE_CONTEXT="${KUBE_CONTEXT:-}"
NS="argocd"
PORT="8081"
DO_OPEN="true"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --context)
      KUBE_CONTEXT="${2:-}"; shift 2 ;;
    --kubeconfig)
      export KUBECONFIG="${2:-}"; shift 2 ;;
    --namespace|-n)
      NS="${2:-}"; shift 2 ;;
    --port)
      PORT="${2:-}"; shift 2 ;;
    --no-open)
      DO_OPEN="false"; shift ;;
    -h|--help)
      usage; exit 0 ;;
    *)
      echo "Unknown arg: $1" >&2
      usage
      exit 2 ;;
  esac
done

kube_common_init "scripts/argocd-ui.sh"

KUBECTL_CMD=(kubectl)
if [[ -n "${KUBE_CONTEXT}" ]]; then
  KUBECTL_CMD+=(--context "${KUBE_CONTEXT}")
fi

decode_b64() {
  base64 --decode 2>/dev/null || base64 -D
}

open_browser() {
  local url="$1"
  if [[ "${DO_OPEN}" != "true" ]]; then
    return 0
  fi
  if command -v open >/dev/null 2>&1; then
    open "${url}" >/dev/null 2>&1 || true
  elif command -v xdg-open >/dev/null 2>&1; then
    xdg-open "${url}" >/dev/null 2>&1 || true
  fi
}

server_insecure="$(${KUBECTL_CMD[@]} -n "${NS}" get configmap argocd-cmd-params-cm -o jsonpath='{.data.server\.insecure}' 2>/dev/null || true)"
server_insecure="$(echo "${server_insecure}" | tr '[:upper:]' '[:lower:]' | xargs || true)"

scheme="https"
svc_port="443"
if [[ "${server_insecure}" == "true" || "${server_insecure}" == "1" ]]; then
  scheme="http"
  svc_port="80"
fi

url="${scheme}://127.0.0.1:${PORT}"

pw_b64="$(${KUBECTL_CMD[@]} -n "${NS}" get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' 2>/dev/null || true)"
if [[ -n "${pw_b64}" ]]; then
  pw="$(printf '%s' "${pw_b64}" | decode_b64)"
  echo "username: admin"
  echo "password: ${pw}"
  echo ""
else
  echo "argocd-initial-admin-secret not found."
  echo "If this cluster was already initialized, use existing credentials."
  echo ""
fi

echo "context:   ${KUBE_CONTEXT:-$(kubectl config current-context 2>/dev/null || echo unknown)}"
echo "namespace: ${NS}"
echo "forward:   svc/argocd-server ${PORT}:${svc_port}"
echo "url:       ${url}"
echo ""

${KUBECTL_CMD[@]} -n "${NS}" port-forward svc/argocd-server "${PORT}:${svc_port}" --address 127.0.0.1 >/tmp/argocd-portforward.log 2>&1 &
PF_PID=$!

cleanup() {
  if kill -0 "${PF_PID}" >/dev/null 2>&1; then
    kill "${PF_PID}" >/dev/null 2>&1 || true
  fi
}
trap cleanup EXIT INT TERM

sleep 0.5
if ! kill -0 "${PF_PID}" >/dev/null 2>&1; then
  echo "Port-forward failed. Logs: /tmp/argocd-portforward.log" >&2
  exit 1
fi

open_browser "${url}"
echo "ArgoCD UI available at: ${url}"
echo "Press Ctrl+C to stop port-forward."

wait "${PF_PID}"
