# Local Kind Test Workflow

This repository includes a local `kind` profile for smoke testing the starter stack.

## What it deploys
- ArgoCD core (installed from upstream manifests)
- security namespaces (kind overlay)
- cert-manager operator
- external-secrets operator
- demo app (`httpbin`)

## Prerequisites
- kind
- kubectl
- kustomize
- kubeconform
- helm (Helm 3 for full static coverage)
- internet access to pull container images and ArgoCD install manifest

## Static validation (run first)
```bash
./scripts/static-validate.sh
```

This checks that key kustomize targets render successfully and validates generated manifests with `kubeconform`.

Explicit modes:
```bash
./scripts/static-validate-fast.sh
./scripts/static-validate-full.sh
```

`static-validate-full.sh` validates all targets and requires Helm 3.
`static-validate-fast.sh` validates non-helm targets only.

## Start cluster and deploy
```bash
./scripts/kind-up.sh
```

The script now waits for:
- ArgoCD core rollout
- `app-of-apps` to reach `Synced` + `Healthy`
- child applications to be created
- expected namespaces (`cert-manager`, `external-secrets`, `demo`) to exist

If reconciliation fails, the script prints ArgoCD diagnostics before exiting.

The scripts pin all `kubectl` commands to `kind-homelab-starter` so they do not depend on your global `kubectl` current-context.

## Check status
```bash
./scripts/kind-status.sh
```

## Validate end-to-end readiness
```bash
./scripts/kind-validate.sh
```

Validation checks:
- ArgoCD applications are `Synced` and `Healthy`
- required namespaces exist
- pods are `Ready` in `cert-manager`, `external-secrets`, and `demo`

## Access ArgoCD UI
```bash
kubectl -n argocd port-forward svc/argocd-server 8081:80
```
Open: `http://localhost:8081`

## Tear down
```bash
./scripts/kind-down.sh
```

## Notes
- This is a local smoke profile, not the full cloud profile.
- It intentionally avoids components that require environment-specific secrets.
- CI uses the same workflow in `.github/workflows/kind-validate.yml`.
