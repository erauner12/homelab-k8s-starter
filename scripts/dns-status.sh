#!/usr/bin/env bash
set -euo pipefail

VERIFY=false
JSON=false
KUBE_CONTEXT="${KUBE_CONTEXT:-}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/lib/kube-common.sh"

usage() {
  cat <<USAGE
Usage: $0 [--verify] [--json] [--context <name>]

Show exposure DNS status for starter repo patterns:
- HTTPRoutes (Cloudflare/External-DNS path)
- Tailscale ingresses (ingressClassName=tailscale)

Options:
  --verify          verify DNS resolution (slower)
  --json            output JSON
  --context <name>  kubectl context to use
  -h, --help        show this help
USAGE
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --verify)
      VERIFY=true; shift ;;
    --json)
      JSON=true; shift ;;
    --context)
      KUBE_CONTEXT="$2"; shift 2 ;;
    -h|--help)
      usage; exit 0 ;;
    *)
      echo "Unknown option: $1" >&2
      usage
      exit 1 ;;
  esac
done

if ! command -v jq >/dev/null 2>&1; then
  echo "jq is required." >&2
  exit 1
fi

kube_common_init "scripts/dns-status.sh"

routes_json="$(${KUBECTL_CMD[@]} get httproutes -A -o json)"
ing_json="$(${KUBECTL_CMD[@]} get ingress -A -o json)"

routes_rows="$(printf '%s' "$routes_json" | jq -r '
  .items[]
  | select((.spec.hostnames // []) | length > 0)
  | [
      .metadata.namespace,
      .metadata.name,
      (.spec.hostnames[0] // "-"),
      (.metadata.annotations["external-dns.alpha.kubernetes.io/target"] // "-"),
      (.metadata.annotations["external-dns.alpha.kubernetes.io/cloudflare-proxied"] // "-")
    ]
  | @tsv
' | sort)"

tailscale_rows="$(printf '%s' "$ing_json" | jq -r '
  .items[]
  | select(.spec.ingressClassName == "tailscale")
  | [
      .metadata.namespace,
      .metadata.name,
      (.status.loadBalancer.ingress[0].hostname // "pending")
    ]
  | @tsv
' | sort)"

if $JSON; then
  printf '{\n'
  printf '  "httproutes": %s,\n' "$(printf '%s' "$routes_json" | jq '[.items[] | select((.spec.hostnames // []) | length > 0) | {namespace: .metadata.namespace, name: .metadata.name, hostname: .spec.hostnames[0], external_dns_target: (.metadata.annotations["external-dns.alpha.kubernetes.io/target"] // null), cloudflare_proxied: (.metadata.annotations["external-dns.alpha.kubernetes.io/cloudflare-proxied"] // null)}]')"
  printf '  "tailscale_ingresses": %s\n' "$(printf '%s' "$ing_json" | jq '[.items[] | select(.spec.ingressClassName == "tailscale") | {namespace: .metadata.namespace, name: .metadata.name, hostname: (.status.loadBalancer.ingress[0].hostname // "pending")}]')"
  printf '}\n'
  exit 0
fi

echo ""
echo "DNS status for HTTPRoutes and Tailscale ingresses"
echo "================================================="
echo ""

echo "HTTPROUTES (Cloudflare/External-DNS pattern)"
echo "-------------------------------------------------"
printf "%-20s %-30s %-45s %-30s %-10s\n" "NAMESPACE" "NAME" "HOSTNAME" "DNS TARGET" "PROXIED"
echo ""

if [[ -n "$routes_rows" ]]; then
  while IFS=$'\t' read -r ns name hostname target proxied; do
    [[ -z "$ns" ]] && continue
    printf "%-20s %-30s %-45s %-30s %-10s\n" "$ns" "$name" "$hostname" "$target" "$proxied"
    if $VERIFY; then
      cf_ip="$(dig +short "$hostname" @1.1.1.1 | head -1 || true)"
      echo "  verify: cloudflare_dns=${cf_ip:-none}"
    fi
  done <<< "$routes_rows"
else
  echo "(none)"
fi

echo ""
echo "TAILSCALE SERVICES (ingressClassName=tailscale)"
echo "-------------------------------------------------"
printf "%-20s %-30s %-45s\n" "NAMESPACE" "NAME" "MAGICDNS HOSTNAME"
echo ""

if [[ -n "$tailscale_rows" ]]; then
  while IFS=$'\t' read -r ns name host; do
    [[ -z "$ns" ]] && continue
    printf "%-20s %-30s %-45s\n" "$ns" "$name" "$host"
    if $VERIFY; then
      ts_ip="$(dig +short "$host" @100.100.100.100 | head -1 || true)"
      echo "  verify: tailscale_dns=${ts_ip:-none}"
    fi
  done <<< "$tailscale_rows"
else
  echo "(none)"
fi

echo ""
hr_count="$(printf '%s' "$routes_json" | jq '[.items[] | select((.spec.hostnames // []) | length > 0)] | length')"
ts_count="$(printf '%s' "$ing_json" | jq '[.items[] | select(.spec.ingressClassName == "tailscale")] | length')"
echo "Summary: ${hr_count} httproutes | ${ts_count} tailscale ingresses"
