# Scripts

This starter contains only ArgoCD-focused helper scripts.

## Included
- `pre-bootstrap-test.sh`: validates local prerequisites
- `static-validate.sh`: auto-select full/fast static validation
- `static-validate-fast.sh`: kustomize render + kubeconform (non-helm targets)
- `static-validate-full.sh`: kustomize render + kubeconform (all targets, requires Helm 3)
- `kind-up.sh`: create local kind cluster and bootstrap ArgoCD
- `kind-status.sh`: inspect local kind deployment status
- `kind-validate.sh`: validate ArgoCD sync and pod readiness
- `kind-down.sh`: delete local kind cluster
- `talos/local-up.sh`: create local Talos cluster and apply kind-profile bootstrap (single-cluster guard enabled; set `ALLOW_MULTI_CLUSTER=true` to override)
  - Docker provisioner note: Longhorn is skipped by default because Talos-in-Docker lacks `iscsiadm`; set `ALLOW_UNSUPPORTED_LONGHORN_DOCKER=true` to force.
  - Bootstrap profiles:
    - `BOOTSTRAP_PROFILE=erauner-colos` (auto-picks no-longhorn bootstrap when Longhorn is disabled)
    - `BOOTSTRAP_PROFILE=erauner-colos-no-longhorn` (always no-longhorn bootstrap)
- `talos/local-status.sh`: show Talos cluster and kube context status
- `talos/local-down.sh`: destroy local Talos cluster
- `argocd-get-admin.sh`: print ArgoCD admin credentials for the selected cluster context
- `argocd-ui.sh`: port-forward ArgoCD UI and print admin credentials
- `argocd-create-deploy-key.sh`: creates repository deploy key and ArgoCD repo secret
- `dns-status.sh`: list HTTPRoute and Tailscale DNS status for the active cluster
- `openclaw-access.sh`: compatibility wrapper to `scripts/openclaw/access.sh`
- `sops.sh`: helper utilities for SOPS file handling

OpenClaw-focused scripts are under `scripts/openclaw/`.

If additional scripts are needed, add them with ArgoCD-only scope.
