#!/usr/bin/env bash

# Common kubectl bootstrap for starter scripts.
# Expects optional KUBE_CONTEXT var from caller.

kube_common_init() {
  local caller_script="$1"
  local caller_path
  local script_dir
  local repo_root
  local default_kubeconfig

  caller_path="${BASH_SOURCE[1]}"
  script_dir="$(cd "$(dirname "$caller_path")" && pwd)"

  # Resolve repo root by walking up until terraform/rackspace-spot exists.
  repo_root="$script_dir"
  while [[ "$repo_root" != "/" ]]; do
    if [[ -d "$repo_root/terraform/rackspace-spot" ]]; then
      break
    fi
    repo_root="$(dirname "$repo_root")"
  done

  if [[ "$repo_root" == "/" ]]; then
    # Fallback for older layout assumptions.
    repo_root="$(cd "${script_dir}/.." && pwd)"
  fi

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
    cat >&2 <<EOF
kubectl cannot reach a cluster.
Set one of:
  KUBECONFIG=terraform/rackspace-spot/kubeconfig-starter-cloud.yaml
or:
  ./${caller_script} --context <your-context>
EOF
    return 1
  fi
}
