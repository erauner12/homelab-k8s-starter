#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/lib/kube-common.sh
source "${SCRIPT_DIR}/lib/kube-common.sh"

usage() {
  cat <<'USAGE'
Usage:
  scripts/argocd-get-admin.sh [--context <kubectl-context>] [--kubeconfig <path>] [--namespace <ns>] [--url <argocd-url>]

Defaults:
  --context    current kubectl context (or KUBE_CONTEXT env)
  --kubeconfig respects KUBECONFIG if set
  --namespace  argocd
  --url        read from argocd-cm.data.url when available

Example:
  scripts/argocd-get-admin.sh --context starter-talos-e2e10
USAGE
}

KUBE_CONTEXT="${KUBE_CONTEXT:-}"
NS="argocd"
URL_OVERRIDE=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --context)
      KUBE_CONTEXT="${2:-}"; shift 2 ;;
    --kubeconfig)
      export KUBECONFIG="${2:-}"; shift 2 ;;
    --namespace|-n)
      NS="${2:-}"; shift 2 ;;
    --url)
      URL_OVERRIDE="${2:-}"; shift 2 ;;
    -h|--help)
      usage; exit 0 ;;
    *)
      echo "Unknown arg: $1" >&2
      usage
      exit 2 ;;
  esac
done

kube_common_init "scripts/argocd-get-admin.sh"

KUBECTL_CMD=(kubectl)
if [[ -n "${KUBE_CONTEXT}" ]]; then
  KUBECTL_CMD+=(--context "${KUBE_CONTEXT}")
fi

decode_b64() {
  base64 --decode 2>/dev/null || base64 -D
}

url_from_cm="$(${KUBECTL_CMD[@]} -n "${NS}" get configmap argocd-cm -o jsonpath='{.data.url}' 2>/dev/null || true)"
url="${URL_OVERRIDE:-${url_from_cm}}"

pw_b64="$(${KUBECTL_CMD[@]} -n "${NS}" get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' 2>/dev/null || true)"
if [[ -z "${pw_b64}" ]]; then
  echo "argocd-initial-admin-secret not found in namespace ${NS}."
  echo "This is normal if the initial admin secret was deleted after first login."
  exit 1
fi

pw="$(printf '%s' "${pw_b64}" | decode_b64)"

echo "ArgoCD admin access"
echo "context:   ${KUBE_CONTEXT:-$(kubectl config current-context 2>/dev/null || echo unknown)}"
echo "namespace: ${NS}"
if [[ -n "${url}" ]]; then
  echo "url:       ${url}"
else
  echo "url:       not configured in argocd-cm (use local port-forward)"
fi
echo "username:  admin"
echo "password:  ${pw}"
echo ""
echo "CLI login example:"
if [[ -n "${url}" ]]; then
  echo "argocd login ${url#http://} --username admin --password '${pw}' --grpc-web"
else
  echo "kubectl -n ${NS} port-forward svc/argocd-server 8081:80"
  echo "argocd login 127.0.0.1:8081 --plaintext --username admin --password '${pw}'"
fi
