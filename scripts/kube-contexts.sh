#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=./lib/kube-common.sh
source "${SCRIPT_DIR}/lib/kube-common.sh"

SHOW_ALL=false
VERIFY=false
OUTPUT_JSON=false

usage() {
  cat <<USAGE
Usage: $0 [options]

Options:
  --all       Show all kube contexts (default: repo-related only)
  --verify    Test API reachability for each listed context (5s timeout)
  --json      Emit JSON output
  -h, --help  Show help

Examples:
  $0
  $0 --verify
  $0 --all --verify
USAGE
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --all) SHOW_ALL=true; shift ;;
    --verify) VERIFY=true; shift ;;
    --json) OUTPUT_JSON=true; shift ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown option: $1"; usage; exit 1 ;;
  esac
done

repo_root="$(kube_common_repo_root "$SCRIPT_DIR")"
local_prefix="$(kube_common_local_prefix)"
cloud_contexts="$(kube_common_cloud_contexts "$repo_root")"
all_contexts="$(kubectl config get-contexts -o name 2>/dev/null || true)"
current_context="$(kubectl config current-context 2>/dev/null || true)"

if [[ "$SHOW_ALL" == "true" ]]; then
  contexts="$all_contexts"
else
  contexts="$(kube_common_repo_contexts "$repo_root")"
fi

contexts="$(printf '%s\n' "$contexts" | sed '/^$/d' | sort -u)"

if [[ -z "$contexts" ]]; then
  if [[ "$OUTPUT_JSON" == "true" ]]; then
    echo '[]'
  else
    echo "No kube contexts found for selection."
  fi
  exit 0
fi

context_source() {
  local ctx="$1"
  if [[ "$ctx" =~ ^${local_prefix}($|-) ]]; then
    echo "local"
    return
  fi
  if printf '%s\n' "$cloud_contexts" | grep -Fxq "$ctx"; then
    echo "cloud"
    return
  fi
  echo "other"
}

context_reachable() {
  local ctx="$1"
  if [[ "$VERIFY" != "true" ]]; then
    echo "n/a"
    return
  fi
  if kubectl --context "$ctx" version --request-timeout=5s >/dev/null 2>&1; then
    echo "ok"
  else
    echo "fail"
  fi
}

if [[ "$OUTPUT_JSON" == "true" ]]; then
  echo '['
  first=true
  while IFS= read -r ctx; do
    [[ -z "$ctx" ]] && continue
    src="$(context_source "$ctx")"
    reach="$(context_reachable "$ctx")"
    current="false"
    if [[ "$ctx" == "$current_context" ]]; then
      current="true"
    fi

    if [[ "$first" == "false" ]]; then
      echo ','
    fi
    first=false
    printf '  {"context":"%s","source":"%s","current":%s,"reachable":"%s"}' "$ctx" "$src" "$current" "$reach"
  done <<< "$contexts"
  echo
  echo ']'
  exit 0
fi

printf '%-40s %-8s %-8s %-10s\n' "CONTEXT" "SOURCE" "CURRENT" "REACHABLE"
printf '%-40s %-8s %-8s %-10s\n' "-------" "------" "-------" "---------"
while IFS= read -r ctx; do
  [[ -z "$ctx" ]] && continue
  src="$(context_source "$ctx")"
  reach="$(context_reachable "$ctx")"
  current=""
  if [[ "$ctx" == "$current_context" ]]; then
    current="*"
  fi
  printf '%-40s %-8s %-8s %-10s\n' "$ctx" "$src" "$current" "$reach"
done <<< "$contexts"
