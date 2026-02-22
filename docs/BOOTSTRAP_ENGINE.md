# Bootstrap Engine Guide (ArgoCD)

This starter bootstraps ArgoCD app-of-apps on an existing Kubernetes cluster.

## Prerequisites
- Kubernetes cluster access (`kubectl get nodes`)
- GitHub CLI authenticated (`gh auth status`)
- SOPS age key for secret workflow
- SSH key for repository deploy access

## Run
```bash
./bin/homelabctl bootstrap plan
./bin/homelabctl bootstrap run --kubeconfig ~/.kube/config
```

## What bootstrap does
1. Preflight checks
2. Cluster readiness checks
3. ArgoCD runtime install
4. Required secret creation
5. App-of-apps apply from `clusters/cloud/bootstrap`
6. Sync verification and smoke checks

## Verification
```bash
kubectl -n argocd get applications
kubectl get pods -n cert-manager
kubectl get pods -n tailscale
```
