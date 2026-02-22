#!/usr/bin/env bash

# Common kubectl bootstrap for starter scripts.
# Expects optional KUBE_CONTEXT var from caller.

kube_common_repo_root() {
  local script_dir="$1"
  local repo_root

  repo_root="$script_dir"
  while [[ "$repo_root" != "/" ]]; do
    if [[ -d "$repo_root/terraform/rackspace-spot" ]]; then
      printf '%s\n' "$repo_root"
      return 0
    fi
    repo_root="$(dirname "$repo_root")"
  done

  # Fallback for older layout assumptions.
  repo_root="$(cd "${script_dir}/.." && pwd)"
  printf '%s\n' "$repo_root"
}

kube_common_local_prefix() {
  printf '%s\n' "${CLUSTER_NAME:-starter-talos}"
}

kube_common_cloud_contexts() {
  local repo_root="$1"
  local default_kubeconfig

  default_kubeconfig="${repo_root}/terraform/rackspace-spot/kubeconfig-starter-cloud.yaml"
  if [[ ! -f "$default_kubeconfig" ]]; then
    return 0
  fi

  awk '/^[[:space:]]*- context:/ {in_context=1; next} in_context && /^[[:space:]]*name:[[:space:]]+/ {print $2; in_context=0}' "$default_kubeconfig" 2>/dev/null || true
}

kube_common_repo_contexts() {
  local repo_root="$1"
  local local_prefix cloud_contexts all_contexts

  local_prefix="$(kube_common_local_prefix)"
  cloud_contexts="$(kube_common_cloud_contexts "$repo_root")"
  all_contexts="$(kubectl config get-contexts -o name 2>/dev/null || true)"

  {
    printf '%s\n' "$all_contexts" | awk -v pfx="$local_prefix" 'pfx != "" && $0 ~ ("^" pfx "($|-)" ) {print}'
    printf '%s\n' "$all_contexts" | while IFS= read -r ctx; do
      [[ -z "$ctx" ]] && continue
      if printf '%s\n' "$cloud_contexts" | grep -Fxq "$ctx"; then
        printf '%s\n' "$ctx"
      fi
    done
  } | sed '/^$/d' | sort -u
}

kube_common_print_repo_contexts() {
  local repo_root="$1"
  local contexts

  contexts="$(kube_common_repo_contexts "$repo_root")"
  if [[ -z "$contexts" ]]; then
    echo "No repo-related kube contexts detected." >&2
    return 0
  fi

  echo "Repo-related kube contexts:" >&2
  printf '%s\n' "$contexts" | sed 's/^/  - /' >&2
}

kube_common_init() {
  local caller_script="$1"
  local caller_path
  local script_dir
  local repo_root
  local default_kubeconfig

  caller_path="${BASH_SOURCE[1]}"
  script_dir="$(cd "$(dirname "$caller_path")" && pwd)"
  repo_root="$(kube_common_repo_root "$script_dir")"
  default_kubeconfig="${repo_root}/terraform/rackspace-spot/kubeconfig-starter-cloud.yaml"

  KUBECTL_CMD=(kubectl)
  if [[ -n "${KUBE_CONTEXT:-}" ]]; then
    KUBECTL_CMD+=(--context "$KUBE_CONTEXT")
  fi

  if [[ -z "${KUBECONFIG:-}" ]] && [[ -z "${KUBE_CONTEXT:-}" ]] && [[ -f "$default_kubeconfig" ]]; then
    export KUBECONFIG="$default_kubeconfig"
    echo "Using kubeconfig: $KUBECONFIG" >&2
  fi

  if ! "${KUBECTL_CMD[@]}" version --request-timeout=10s >/dev/null 2>&1; then
    cat >&2 <<EOF_ERR
kubectl cannot reach a cluster.
Set one of:
  KUBECONFIG=terraform/rackspace-spot/kubeconfig-starter-cloud.yaml
or:
  ./${caller_script} --context <your-context>

You can inspect repo-related contexts with:
  ./scripts/kube-contexts.sh
EOF_ERR
    kube_common_print_repo_contexts "$repo_root"
    return 1
  fi
}
