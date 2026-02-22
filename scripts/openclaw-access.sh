#!/usr/bin/env bash
set -euo pipefail

NAMESPACE="ai"
INGRESS_NAME="openclaw-tailscale"
SECRET_NAME="openclaw-gateway-auth"
SECRET_KEY="gateway-token"
KUBE_CONTEXT="${KUBE_CONTEXT:-}"
COPY=false
SHOW_URL_ONLY=false
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/lib/kube-common.sh"

usage() {
  cat <<USAGE
Usage: $0 [--context <name>] [--copy-token] [--url-only]

Print OpenClaw access details from Kubernetes:
- Tailscale URL from ingress status
- Gateway token from Kubernetes Secret

Options:
  --context <name>  kubectl context to use
  --copy-token      copy token to clipboard (macOS pbcopy)
  --url-only        print URL only
  -h, --help        show this help

Examples:
  KUBECONFIG=terraform/rackspace-spot/kubeconfig-starter-cloud.yaml $0
  $0 --context kind-homelab-operator-e2e --url-only
USAGE
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --context)
      KUBE_CONTEXT="$2"; shift 2 ;;
    --copy-token)
      COPY=true; shift ;;
    --url-only)
      SHOW_URL_ONLY=true; shift ;;
    -h|--help)
      usage; exit 0 ;;
    *)
      echo "Unknown option: $1" >&2
      usage
      exit 1 ;;
  esac
done

kube_common_init "scripts/openclaw-access.sh"

host="$(${KUBECTL_CMD[@]} -n "$NAMESPACE" get ingress "$INGRESS_NAME" -o jsonpath='{.status.loadBalancer.ingress[0].hostname}' 2>/dev/null || true)"
if [[ -z "$host" ]]; then
  echo "Failed to read ingress hostname from ${NAMESPACE}/${INGRESS_NAME}." >&2
  echo "Check that OpenClaw and Tailscale ingress are deployed." >&2
  exit 1
fi

url="https://${host}/"

if $SHOW_URL_ONLY; then
  echo "$url"
  exit 0
fi

token_b64="$(${KUBECTL_CMD[@]} -n "$NAMESPACE" get secret "$SECRET_NAME" -o jsonpath="{.data.${SECRET_KEY}}" 2>/dev/null || true)"
if [[ -z "$token_b64" ]]; then
  echo "Failed to read token from secret ${NAMESPACE}/${SECRET_NAME} key ${SECRET_KEY}." >&2
  exit 1
fi

token="$(printf '%s' "$token_b64" | base64 --decode)"

echo "OpenClaw URL:"
echo "  ${url}"
echo ""
echo "Gateway token (paste into Control UI settings):"
echo "  ${token}"
echo ""
echo "Flow:"
echo "  1. Open ${url}"
echo "  2. Open settings in the UI"
echo "  3. Paste token above into gateway token field"

if $COPY; then
  if command -v pbcopy >/dev/null 2>&1; then
    printf '%s' "$token" | pbcopy
    echo ""
    echo "Token copied to clipboard."
  else
    echo ""
    echo "pbcopy not found; cannot copy token automatically."
  fi
fi
