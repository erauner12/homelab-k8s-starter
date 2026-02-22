# Secrets Checklist

This starter repo keeps only templates. Do not commit real secrets.

## Required for local kind profile
- None by default for base smoke profile.

## Required for cloud profile
1. ArgoCD repository credentials
   - Template: `secrets/templates/argocd-repository-secret.example.yaml`
   - Namespace: `argocd`

2. External provider/API secrets as needed by enabled components
   - Cloudflare token template: `secrets/templates/cloudflare-api-token.sops.example.yaml`
   - Tailscale operator OAuth template: `secrets/templates/tailscale-operator-oauth-secret.sops.example.yaml`
   - Tailscale operator GitOps secret path: `operators/tailscale-operator/base/operator-oauth-secret.sops.yaml`

## Recommended workflow
1. Copy template to a local working file.
2. Fill values.
3. Encrypt with SOPS if you keep it in Git.
4. Apply with `kubectl apply -f <file>`.

## Validation
Use:
```bash
kubectl -n argocd get secret homelab-k8s-repo
kubectl -n network get secret cloudflare-api-token
kubectl -n tailscale get secret operator-oauth
```
