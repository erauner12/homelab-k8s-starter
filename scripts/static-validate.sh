#!/usr/bin/env bash
set -euo pipefail

KUBE_VERSION="${KUBE_VERSION:-1.32.0}"

require() {
  command -v "$1" >/dev/null 2>&1 || { echo "[ERR] missing tool: $1"; exit 1; }
}

require kustomize
require kubeconform
require helm

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

HELM_REQUIRED_PATHS=(
  "operators/cert-manager/overlays/erauner-cloud"
  "operators/external-secrets/overlays/erauner-cloud"
)

TMP_DIR="$(mktemp -d)"
ALL_MANIFESTS="${TMP_DIR}/all-manifests.yaml"

cleanup() {
  rm -rf "${TMP_DIR}"
}
trap cleanup EXIT

: > "${ALL_MANIFESTS}"

supports_kustomize_helm=true
if ! helm version -c --short >/dev/null 2>&1; then
  supports_kustomize_helm=false
  echo "[WARN] helm does not support 'helm version -c --short'; skipping helm-backed targets"
  echo "[WARN] install Helm 3 for full static coverage"
fi

echo "[INFO] rendering kustomize targets"
for path in "${KUSTOMIZE_PATHS[@]}"; do
  skip_path=false
  for helm_path in "${HELM_REQUIRED_PATHS[@]}"; do
    if [[ "${path}" == "${helm_path}" && "${supports_kustomize_helm}" == "false" ]]; then
      echo "[WARN] skipping ${path} (requires Helm 3 for kustomize --enable-helm)"
      skip_path=true
      break
    fi
  done
  if [[ "${skip_path}" == "true" ]]; then
    continue
  fi

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

echo "[OK] static validation passed"
