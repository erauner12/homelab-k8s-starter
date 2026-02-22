# Tailscale Operator (Optional)

The starter includes a Tailscale operator app manifest, but it is optional until OAuth credentials are configured.

## 1. Create OAuth secret

Template:
- `secrets/templates/tailscale-operator-oauth-secret.sops.example.yaml`

Create encrypted secret file for GitOps at:
- `operators/tailscale-operator/base/operator-oauth-secret.sops.yaml`

## 2. Enable optional app set

Edit:
- `clusters/cloud/argocd/operators/kustomization.yaml`

Add:
- `tailscale-operator-app.yaml`

Or apply optional kustomization directly for review:
- `clusters/cloud/argocd/operators/kustomization.optional.yaml`

## 3. Verify

- `kubectl -n tailscale get pods`
- `kubectl -n argocd get application tailscale-operator`
