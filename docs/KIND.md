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
- internet access to pull container images and ArgoCD install manifest

## Start cluster and deploy
```bash
./scripts/kind-up.sh
```

## Check status
```bash
./scripts/kind-status.sh
```

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
