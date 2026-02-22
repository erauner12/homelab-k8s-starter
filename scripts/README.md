# Scripts

This starter contains only ArgoCD-focused helper scripts.

## Included
- `pre-bootstrap-test.sh`: validates local prerequisites
- `static-validate.sh`: kustomize render + kubeconform schema checks
- `kind-up.sh`: create local kind cluster and bootstrap ArgoCD
- `kind-status.sh`: inspect local kind deployment status
- `kind-validate.sh`: validate ArgoCD sync and pod readiness
- `kind-down.sh`: delete local kind cluster
- `argocd-create-deploy-key.sh`: creates repository deploy key and ArgoCD repo secret
- `sops.sh`: helper utilities for SOPS file handling

If additional scripts are needed, add them with ArgoCD-only scope.
