#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
TALOS_DIR="${TALOS_DIR:-${ROOT_DIR}/.talos}"
TALOS_STATE_DIR="${TALOS_STATE_DIR:-${TALOS_DIR}/clusters}"
TALOSCONFIG_PATH="${TALOSCONFIG_PATH:-${TALOS_DIR}/config}"
CLUSTER_NAME="${CLUSTER_NAME:-starter-talos}"
PROVISIONER="${PROVISIONER:-docker}"
CONTROLPLANES="${CONTROLPLANES:-1}"
WORKERS="${WORKERS:-1}"
KUBERNETES_VERSION="${KUBERNETES_VERSION:-1.31.5}"
CIDR="${CIDR:-10.5.0.0/24}"
WAIT_TIMEOUT="${WAIT_TIMEOUT:-20m}"
BOOTSTRAP_PROFILE="${BOOTSTRAP_PROFILE:-erauner-colos}"
CILIUM_WAIT_TIMEOUT="${CILIUM_WAIT_TIMEOUT:-600s}"
LONGHORN_WAIT_TIMEOUT="${LONGHORN_WAIT_TIMEOUT:-1200s}"
ENABLE_LONGHORN="${ENABLE_LONGHORN:-true}"
APPLY_NODEIP_PATCH="${APPLY_NODEIP_PATCH:-false}"
TALOS_CREATE_WAIT="${TALOS_CREATE_WAIT:-false}"
ALLOW_MULTI_CLUSTER="${ALLOW_MULTI_CLUSTER:-false}"
ALLOW_UNSUPPORTED_LONGHORN_DOCKER="${ALLOW_UNSUPPORTED_LONGHORN_DOCKER:-false}"
ALLOW_OTHER_K8S_CONTAINERS="${ALLOW_OTHER_K8S_CONTAINERS:-false}"

require() {
  command -v "$1" >/dev/null 2>&1 || { echo "[ERR] missing tool: $1"; exit 1; }
}

require talosctl
require kubectl
if [[ "${PROVISIONER}" == "docker" ]]; then
  require docker
fi

mkdir -p "${TALOS_STATE_DIR}" "$(dirname "${TALOSCONFIG_PATH}")"
export TALOSCONFIG="${TALOSCONFIG_PATH}"

if [[ "${PROVISIONER}" == "docker" && "${ALLOW_MULTI_CLUSTER}" != "true" ]]; then
  existing_clusters="$(
    docker ps --filter label=talos.owned=true --format '{{.Label "talos.cluster.name"}}' \
      | sed '/^$/d' | sort -u
  )"
  other_clusters="$(printf '%s\n' "${existing_clusters}" | rg -v "^${CLUSTER_NAME}$" || true)"
  if [[ -n "${other_clusters}" ]]; then
    echo "[ERR] found other running Talos cluster(s):"
    printf '%s\n' "${other_clusters}" | sed 's/^/  - /'
    echo "[ERR] destroy them first, or set ALLOW_MULTI_CLUSTER=true to override."
    exit 1
  fi
fi

if [[ "${PROVISIONER}" == "docker" && "${ALLOW_OTHER_K8S_CONTAINERS}" != "true" ]]; then
  # Guard against unrelated local cluster containers consuming resources and causing flaky API timeouts.
  other_k8s_containers="$(
    docker ps --format '{{.Names}}' \
      | rg 'control-plane|worker|kind-' \
      | rg -v "^${CLUSTER_NAME}-(controlplane|worker)-" || true
  )"
  if [[ -n "${other_k8s_containers}" ]]; then
    echo "[ERR] found other running k8s-style Docker containers:"
    printf '%s\n' "${other_k8s_containers}" | sed 's/^/  - /'
    echo "[ERR] stop them first to avoid local API instability,"
    echo "[ERR] or set ALLOW_OTHER_K8S_CONTAINERS=true to override."
    exit 1
  fi
fi

if [[ "${PROVISIONER}" == "docker" && "${ENABLE_LONGHORN}" == "true" && "${ALLOW_UNSUPPORTED_LONGHORN_DOCKER}" != "true" ]]; then
  echo "[WARN] Longhorn requires host iSCSI tools (iscsiadm) that are not available in Talos-in-Docker by default."
  echo "[WARN] Skipping Longhorn for docker provisioner. Set ALLOW_UNSUPPORTED_LONGHORN_DOCKER=true to force."
  ENABLE_LONGHORN="false"
fi

cidr_base="${CIDR%%/*}"
IFS='.' read -r oct1 oct2 oct3 oct4 <<< "${cidr_base}"
if [[ -z "${oct1:-}" || -z "${oct2:-}" || -z "${oct3:-}" ]]; then
  echo "[ERR] invalid CIDR: ${CIDR}"
  exit 1
fi
K8S_API_HOST="${oct1}.${oct2}.${oct3}.2"

tmp_dir="$(mktemp -d)"
cleanup() {
  rm -rf "${tmp_dir}"
}
trap cleanup EXIT

cluster_patch="${tmp_dir}/cluster-base.rendered.yaml"
longhorn_patch="${tmp_dir}/longhorn-install.rendered.yaml"
sed "s/__K8S_API_HOST__/${K8S_API_HOST}/g" "${ROOT_DIR}/talos/patches/cluster-base.yaml" > "${cluster_patch}"
sed "s/__K8S_API_HOST__/${K8S_API_HOST}/g" "${ROOT_DIR}/talos/patches/longhorn-install.yaml" > "${longhorn_patch}"

create_args=(
  --name "${CLUSTER_NAME}"
  --state "${TALOS_STATE_DIR}"
  --talosconfig "${TALOSCONFIG_PATH}"
  --provisioner "${PROVISIONER}"
  --controlplanes "${CONTROLPLANES}"
  --workers "${WORKERS}"
  --kubernetes-version "${KUBERNETES_VERSION}"
  --config-patch "@${cluster_patch}"
  --config-patch-control-plane "@${ROOT_DIR}/talos/patches/controlplane-base.yaml"
  --config-patch-control-plane "@${ROOT_DIR}/talos/patches/machine-hostdns.yaml"
  --config-patch-worker "@${ROOT_DIR}/talos/patches/worker-base.yaml"
  --config-patch-worker "@${ROOT_DIR}/talos/patches/machine-hostdns.yaml"
)

if [[ -n "${CIDR}" ]]; then
  create_args+=(--cidr "${CIDR}")
fi

if [[ "${APPLY_NODEIP_PATCH}" == "true" ]]; then
  create_args+=(
    --config-patch-control-plane "@${ROOT_DIR}/talos/patches/machine-kubelet.yaml"
    --config-patch-worker "@${ROOT_DIR}/talos/patches/machine-kubelet.yaml"
  )
fi

if [[ "${ENABLE_LONGHORN}" == "true" ]]; then
  create_args+=(--config-patch "@${longhorn_patch}")
fi

if [[ "${TALOS_CREATE_WAIT}" == "true" ]]; then
  create_args+=(--wait-timeout "${WAIT_TIMEOUT}" --wait)
else
  create_args+=(--wait=false)
fi

echo "[INFO] creating local Talos cluster: ${CLUSTER_NAME}"
echo "[INFO] longhorn enabled: ${ENABLE_LONGHORN}"
echo "[INFO] CIDR: ${CIDR} (api host: ${K8S_API_HOST})"
talosctl cluster create "${create_args[@]}"

CLUSTER_SHOW="$(talosctl cluster show --name "${CLUSTER_NAME}")"
CONTROLPLANE_LINE="$(printf '%s\n' "${CLUSTER_SHOW}" | awk '/controlplane/ {print; exit}')"
CONTROLPLANE_IP="$(printf '%s\n' "${CONTROLPLANE_LINE}" | grep -Eo '([0-9]{1,3}\.){3}[0-9]{1,3}' | head -n1 || true)"
KUBERNETES_ENDPOINT="$(printf '%s\n' "${CLUSTER_SHOW}" | grep 'KUBERNETES ENDPOINT' | grep -Eo 'https://[^ ]+' | head -n1 || true)"
TALOS_CONTEXT="$(talosctl config info | awk -F': *' '/Current context/ {print $2}')"
TALOS_ENDPOINT="$(talosctl --context "${TALOS_CONTEXT}" config info | awk -F': *' '/Endpoints/ {print $2}')"
if [[ "${PROVISIONER}" == "docker" ]]; then
  TALOS_API_PORT="$(docker port "${CLUSTER_NAME}-controlplane-1" 50000/tcp 2>/dev/null | head -n1 | awk -F: '{print $NF}' || true)"
  if [[ -n "${TALOS_API_PORT}" ]]; then
    TALOS_ENDPOINT="127.0.0.1:${TALOS_API_PORT}"
  fi
fi
if [[ -z "${CONTROLPLANE_IP}" ]]; then
  echo "[ERR] failed to determine control plane IP for cluster ${CLUSTER_NAME}"
  exit 1
fi
if [[ -z "${TALOS_ENDPOINT}" ]]; then
  echo "[ERR] failed to determine Talos endpoint for cluster ${CLUSTER_NAME}"
  exit 1
fi

echo "[INFO] fetching kubeconfig from control plane: ${CONTROLPLANE_IP}"
echo "[INFO] using Talos endpoint: ${TALOS_ENDPOINT}"
talosctl --context "${TALOS_CONTEXT}" --nodes "${CONTROLPLANE_IP}" --endpoints "${TALOS_ENDPOINT}" kubeconfig --force --force-context-name "${CLUSTER_NAME}"
if [[ -n "${KUBERNETES_ENDPOINT}" ]]; then
  kubectl config set-cluster "${CLUSTER_NAME}" --server="${KUBERNETES_ENDPOINT}" >/dev/null
fi
kubectl config use-context "${CLUSTER_NAME}" >/dev/null
echo "[INFO] using kube context: ${CLUSTER_NAME}"

echo "[INFO] waiting for nodes"
for _ in $(seq 1 120); do
  if kubectl get nodes --no-headers 2>/dev/null | grep -q .; then
    break
  fi
  sleep 2
done
kubectl wait --for=condition=Ready node --all --timeout=600s

echo "[INFO] waiting for Cilium install job"
kubectl -n cilium wait --for=condition=complete job/cilium-install --timeout="${CILIUM_WAIT_TIMEOUT}"
kubectl -n cilium wait --for=condition=Ready pod -l k8s-app=cilium --timeout="${CILIUM_WAIT_TIMEOUT}"

if [[ "${ENABLE_LONGHORN}" == "true" ]]; then
  echo "[INFO] waiting for Longhorn install job"
  kubectl -n longhorn-system wait --for=condition=complete job/longhorn-install --timeout="${LONGHORN_WAIT_TIMEOUT}"
  kubectl -n longhorn-system wait --for=condition=Ready pod -l app=longhorn-manager --timeout="${LONGHORN_WAIT_TIMEOUT}"
fi

bootstrap_path=""
case "${BOOTSTRAP_PROFILE}" in
  erauner-colos)
    if [[ "${ENABLE_LONGHORN}" == "true" ]]; then
      bootstrap_path="clusters/local/bootstrap"
    else
      bootstrap_path="clusters/local/bootstrap-no-longhorn"
    fi
    ;;
  erauner-colos-no-longhorn)
    bootstrap_path="clusters/local/bootstrap-no-longhorn"
    ;;
  none)
    bootstrap_path=""
    ;;
  *)
    echo "[ERR] unsupported BOOTSTRAP_PROFILE: ${BOOTSTRAP_PROFILE}"
    echo "[ERR] supported values: erauner-colos, erauner-colos-no-longhorn, none"
    exit 1
    ;;
esac

if [[ -n "${bootstrap_path}" ]]; then
  echo "[INFO] installing Argo CD"
  kubectl create namespace argocd --dry-run=client -o yaml | kubectl apply -f -
  kubectl apply --server-side --force-conflicts -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
  kubectl -n argocd rollout status deploy/argocd-server --timeout=600s
  kubectl -n argocd rollout status statefulset/argocd-application-controller --timeout=600s

  echo "[INFO] applying bootstrap profile: ${bootstrap_path}"
  kubectl apply -k "${ROOT_DIR}/${bootstrap_path}"
fi

echo "[OK] local Talos cluster is up"
