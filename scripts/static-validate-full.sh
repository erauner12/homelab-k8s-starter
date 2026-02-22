#!/usr/bin/env bash
set -euo pipefail

KUBE_VERSION="${KUBE_VERSION:-1.32.0}"

require() {
  command -v "$1" >/dev/null 2>&1 || { echo "[ERR] missing tool: $1"; exit 1; }
}

require kustomize
require kubeconform
require helm

if ! helm version -c --short >/dev/null 2>&1; then
  echo "[ERR] static full validation requires Helm 3 (supports 'helm version -c --short')"
  echo "[ERR] current helm: $(helm version --short 2>/dev/null || echo unknown)"
  exit 1
fi

KUSTOMIZE_PATHS=(
  "clusters/kind/bootstrap"
  "clusters/kind/argocd/root"
  "clusters/kind/argocd/operators"
  "clusters/kind/argocd/security"
  "clusters/kind/argocd/apps"
  "clusters/cloud/bootstrap"
  "clusters/cloud/argocd/operators"
  "clusters/cloud/argocd/security"
  "clusters/cloud/argocd/apps"
  "operators/cert-manager/overlays/erauner-cloud"
  "operators/external-secrets/overlays/erauner-cloud"
  "security/namespaces/overlays/kind"
  "security/namespaces/overlays/erauner-cloud"
  "apps/poc-httpbin/base"
)

TMP_DIR="$(mktemp -d)"
ALL_MANIFESTS="${TMP_DIR}/all-manifests.yaml"
GENERATED_CHART_DIRS=(
  "operators/cert-manager/base/charts"
  "operators/external-secrets/base/charts"
)

cleanup() {
  for chart_dir in "${GENERATED_CHART_DIRS[@]}"; do
    rm -rf "${chart_dir}" || true
  done
  rm -rf "${TMP_DIR}"
}
trap cleanup EXIT

: > "${ALL_MANIFESTS}"

echo "[INFO] rendering full kustomize targets"
for path in "${KUSTOMIZE_PATHS[@]}"; do
  if [[ ! -f "${path}/kustomization.yaml" ]]; then
    echo "[ERR] missing kustomization.yaml in ${path}"
    exit 1
  fi

  out_file="${TMP_DIR}/$(echo "${path}" | tr '/.' '__').yaml"
  echo "[INFO] build ${path}"
  kustomize build --enable-helm --load-restrictor=LoadRestrictionsNone "${path}" > "${out_file}"

  if [[ ! -s "${out_file}" ]]; then
    echo "[ERR] empty render output for ${path}"
    exit 1
  fi

  cat "${out_file}" >> "${ALL_MANIFESTS}"
  printf "\n---\n" >> "${ALL_MANIFESTS}"
done

echo "[INFO] validating schemas with kubeconform (kubernetes ${KUBE_VERSION})"
kubeconform \
  -strict \
  -summary \
  -ignore-missing-schemas \
  -kubernetes-version "${KUBE_VERSION}" \
  "${ALL_MANIFESTS}"

echo "[OK] static full validation passed"
