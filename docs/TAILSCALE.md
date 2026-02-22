# Tailscale Operator (Optional)

The starter includes a Tailscale operator app manifest, but it is optional until OAuth credentials are configured.

## 1. Create OAuth secret

Template:
- `secrets/templates/tailscale-operator-oauth-secret.sops.example.yaml`

Apply a Secret named `operator-oauth` in namespace `tailscale` (keys: `client_id`, `client_secret`).

For local testing, you can decrypt and apply from your private repo copy:
```bash
sops -d /path/to/operator-oauth-secret.sops.yaml | kubectl apply -f -
```

## 2. Enable optional app set

Edit:
- `clusters/cloud/argocd/operators/kustomization.yaml`

Add:
- `tailscale-operator-app.yaml`

Or apply optional kustomization directly:
- `clusters/cloud/argocd/operators/kustomization.optional.yaml`

## 3. Verify

- `kubectl -n tailscale get pods`
- `kubectl -n argocd get application tailscale-operator`
