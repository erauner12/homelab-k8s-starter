# Manual Bootstrap Notes (ArgoCD)

This repository is ArgoCD-only.

If you do not use `homelabctl bootstrap run`, the manual flow is:
1. Install ArgoCD runtime.
2. Apply AppProjects.
3. Apply `clusters/cloud/bootstrap`.
4. Verify sync status in ArgoCD.

Preferred path remains:
```bash
./bin/homelabctl bootstrap run --kubeconfig ~/.kube/config
```
