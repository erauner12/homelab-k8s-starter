#!/usr/bin/env bash

# Common kubectl bootstrap for starter scripts.
# Expects optional KUBE_CONTEXT var from caller.

kube_common_init() {
  local caller_script="$1"
  local script_dir
  local repo_root
  local default_kubeconfig

  script_dir="$(cd "$(dirname "${BASH_SOURCE[1]}")" && pwd)"
  repo_root="$(cd "${script_dir}/.." && pwd)"
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
