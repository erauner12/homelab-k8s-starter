#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TF_DIR="${ROOT_DIR}/terraform/rackspace-spot"

CLOUDSPACE_NAME="starter-cloud-$(date +%Y%m%d-%H%M%S)"
REGION="us-east-iad-1"
SERVER_CLASS="gp.vs1.large-iad"
BID_PRICE="0.20"
DESIRED_NODES="1"
DESTROY_ON_EXIT="false"
RUN_OPTIONAL="true"
TEST_URL="https://exposure-demo.erauner.cloud"

usage() {
  cat <<USAGE
Usage: $0 [options]

Options:
  --cloudspace-name <name>     Cloudspace name (default: unique timestamped name)
  --region <region>            Rackspace region (default: ${REGION})
  --server-class <class>       Spot server class (default: ${SERVER_CLASS})
  --bid-price <price>          Spot bid price in USD/hour (default: ${BID_PRICE})
  --desired-nodes <count>      Desired worker count (default: ${DESIRED_NODES})
  --test-url <url>             URL to probe after sync (default: ${TEST_URL})
  --skip-optional              Skip optional cloudflared/exposure-demo apps
  --destroy-on-exit            Destroy cluster at script exit
  -h, --help                   Show this help
USAGE
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --cloudspace-name) CLOUDSPACE_NAME="$2"; shift 2 ;;
    --region) REGION="$2"; shift 2 ;;
    --server-class) SERVER_CLASS="$2"; shift 2 ;;
    --bid-price) BID_PRICE="$2"; shift 2 ;;
    --desired-nodes) DESIRED_NODES="$2"; shift 2 ;;
    --test-url) TEST_URL="$2"; shift 2 ;;
    --skip-optional) RUN_OPTIONAL="false"; shift ;;
    --destroy-on-exit) DESTROY_ON_EXIT="true"; shift ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown option: $1"; usage; exit 1 ;;
  esac
done

require() {
  command -v "$1" >/dev/null 2>&1 || { echo "[ERR] missing tool: $1"; exit 1; }
}

require terraform
require kubectl
require sops
require curl

if [[ -z "${SOPS_AGE_KEY:-}" && -z "${SOPS_AGE_KEY_FILE:-}" ]]; then
  export SOPS_AGE_KEY_FILE="$HOME/.config/sops/age/keys.txt"
fi

cleanup() {
  echo "[INFO] destroy-on-exit enabled; destroying cloudspace ${CLOUDSPACE_NAME}"
  terraform -chdir="${TF_DIR}" destroy -auto-approve \
    -var="cloudspace_name=${CLOUDSPACE_NAME}" \
    -var="region=${REGION}" \
    -var="server_class=${SERVER_CLASS}" \
    -var="autoscaling_enabled=false" \
    -var="desired_node_count=${DESIRED_NODES}" \
    -var="bid_price=${BID_PRICE}" || true
}

if [[ "${DESTROY_ON_EXIT}" == "true" ]]; then
  trap cleanup EXIT
fi

echo "[INFO] apply rackspace cluster: cloudspace=${CLOUDSPACE_NAME} region=${REGION} class=${SERVER_CLASS} bid=${BID_PRICE}"
terraform -chdir="${TF_DIR}" apply -auto-approve \
  -var="cloudspace_name=${CLOUDSPACE_NAME}" \
  -var="region=${REGION}" \
  -var="server_class=${SERVER_CLASS}" \
  -var="autoscaling_enabled=false" \
  -var="desired_node_count=${DESIRED_NODES}" \
  -var="bid_price=${BID_PRICE}"

KUBECONFIG_PATH="${TF_DIR}/$(terraform -chdir="${TF_DIR}" output -raw kubeconfig_path | xargs basename)"
export KUBECONFIG="${KUBECONFIG_PATH}"
echo "[INFO] kubeconfig=${KUBECONFIG}"

for i in $(seq 1 120); do
  echo "[INFO] node check ${i}"
  if kubectl get nodes -o wide 2>/dev/null | awk 'NR>1 {print}' | grep -q .; then
    kubectl get nodes -o wide
    break
  fi
  sleep 10
done
kubectl wait --for=condition=Ready node --all --timeout=480s

echo "[INFO] install argo cd (server-side)"
kubectl create namespace argocd --dry-run=client -o yaml | kubectl apply -f -
kubectl apply --server-side --force-conflicts -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

kubectl -n argocd rollout status deploy/argocd-server --timeout=600s
kubectl -n argocd rollout status statefulset/argocd-application-controller --timeout=600s

echo "[INFO] apply cloud bootstrap"
kubectl apply -k "${ROOT_DIR}/clusters/cloud/bootstrap"

echo "[INFO] run shared smoke checks (cloud profile)"
"${ROOT_DIR}/smoke/scripts/run.sh" --profile cloud

if [[ "${RUN_OPTIONAL}" == "true" ]]; then
  echo "[INFO] enable optional cloudflared and exposure-demo apps"
  kubectl apply -f "${ROOT_DIR}/clusters/cloud/argocd/operators/cloudflared-apps-app.yaml"
  kubectl apply -f "${ROOT_DIR}/clusters/cloud/argocd/apps/exposure-demo-app.yaml"

  echo "[INFO] re-run shared smoke checks after optional app apply"
  "${ROOT_DIR}/smoke/scripts/run.sh" --profile cloud

  kubectl -n network wait --for=condition=Ready pod -l app=cloudflared-apps --timeout=600s
  kubectl -n network get pods -l app=cloudflared-apps -o wide
  kubectl -n demo get deploy,svc,httproute,ingress
  kubectl -n argocd get app cloudflared-apps exposure-demo -o wide

  echo "[INFO] probe ${TEST_URL}"
  for i in $(seq 1 30); do
    code=$(curl -ks -o /tmp/cloud-e2e-url-body.txt -w '%{http_code}' "${TEST_URL}" || true)
    echo "[INFO] url=${TEST_URL} code=${code:-000} attempt=${i}"
    if [[ "${code}" == "200" || "${code}" == "301" || "${code}" == "302" ]]; then
      break
    fi
    sleep 10
  done
  head -n 5 /tmp/cloud-e2e-url-body.txt || true
fi

echo "[OK] cloud e2e finished"
echo "[INFO] cluster left running"
echo "[INFO] destroy when ready: terraform -chdir=${TF_DIR} destroy -auto-approve -var=cloudspace_name=${CLOUDSPACE_NAME} -var=region=${REGION} -var=server_class=${SERVER_CLASS} -var=autoscaling_enabled=false -var=desired_node_count=${DESIRED_NODES} -var=bid_price=${BID_PRICE}"
