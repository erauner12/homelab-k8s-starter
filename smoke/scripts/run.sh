#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
source "${ROOT_DIR}/smoke/scripts/common.sh"

PROFILE="${PROFILE:-auto}"
CHECKS_FILE="${CHECKS_FILE:-}"

usage() {
  cat <<USAGE
Usage: $0 [options]

Options:
  --profile <auto|cloud|local>  Smoke profile (default: auto)
  --checks <path>               Explicit checks yaml path
  --context <name>              kubectl context override
  --kubeconfig <path>           kubeconfig override
  -h, --help                    Show this help
USAGE
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --profile) PROFILE="$2"; shift 2 ;;
    --checks) CHECKS_FILE="$2"; shift 2 ;;
    --context) export KUBE_CONTEXT="$2"; shift 2 ;;
    --kubeconfig) export KUBECONFIG="$2"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown option: $1"; usage; exit 1 ;;
  esac
done

require_cmd kubectl

if [[ "${PROFILE}" == "auto" ]]; then
  case "${KUBECONFIG:-}" in
    *rackspace-spot*) PROFILE="cloud" ;;
    *) PROFILE="local" ;;
  esac
fi

if [[ -z "${CHECKS_FILE}" ]]; then
  case "${PROFILE}" in
    cloud) CHECKS_FILE="${ROOT_DIR}/smoke/checks-cloud.yaml" ;;
    local) CHECKS_FILE="${ROOT_DIR}/smoke/checks-local.yaml" ;;
    *)
      echo "[ERR] invalid profile: ${PROFILE}"
      exit 1
      ;;
  esac
fi

if [[ ! -f "${CHECKS_FILE}" ]]; then
  echo "[ERR] checks file not found: ${CHECKS_FILE}"
  exit 1
fi

echo "[INFO] smoke profile: ${PROFILE}"
echo "[INFO] checks file: ${CHECKS_FILE}"
if [[ -n "${KUBE_CONTEXT:-}" ]]; then
  echo "[INFO] kube context: ${KUBE_CONTEXT}"
fi
if [[ -n "${KUBECONFIG:-}" ]]; then
  echo "[INFO] kubeconfig: ${KUBECONFIG}"
fi

while IFS= read -r app; do
  [[ -z "$app" ]] && continue
  wait_for_app "$app"
done < <(load_yaml_list "${CHECKS_FILE}" apps_required)

while IFS= read -r app; do
  [[ -z "$app" ]] && continue
  if k -n argocd get application "$app" >/dev/null 2>&1; then
    wait_for_app "$app"
  else
    echo "[INFO] optional app not present: ${app}"
  fi
done < <(load_yaml_list "${CHECKS_FILE}" apps_optional)

while IFS= read -r ns; do
  [[ -z "$ns" ]] && continue
  k get ns "$ns" >/dev/null
done < <(load_yaml_list "${CHECKS_FILE}" namespaces_required)

while IFS= read -r ns; do
  [[ -z "$ns" ]] && continue
  if k get ns "$ns" >/dev/null 2>&1; then
    echo "[INFO] optional namespace present: ${ns}"
  else
    echo "[INFO] optional namespace not present: ${ns}"
  fi
done < <(load_yaml_list "${CHECKS_FILE}" namespaces_optional)

while IFS= read -r ns; do
  [[ -z "$ns" ]] && continue
  wait_for_namespace_pods "$ns"
done < <(load_yaml_list "${CHECKS_FILE}" pods_required_namespaces)

while IFS= read -r ns; do
  [[ -z "$ns" ]] && continue
  if k get ns "$ns" >/dev/null 2>&1; then
    wait_for_namespace_pods "$ns"
  else
    echo "[INFO] optional pods namespace not present: ${ns}"
  fi
done < <(load_yaml_list "${CHECKS_FILE}" pods_optional_namespaces)

print_summary
echo "[OK] smoke checks passed"
