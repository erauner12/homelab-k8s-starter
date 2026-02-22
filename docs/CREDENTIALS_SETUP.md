# Credentials Setup Guide

This file is the handoff checklist for replacing owner credentials with your own.

Use this before sharing the repo with someone else.

## What must be replaced

1. SOPS age key seed
- File: `infrastructure/sops-age-seed/overlays/erauner-cloud/sops-age-secret.yaml`
- What it is: private age key used by ArgoCD repo-server to decrypt SOPS files.
- Where to get yours:
  - `age-keygen -o ~/.config/sops/age/age.agekey`
- How to update:
  - replace the `age.agekey` block in the file.
  - update `.sops.yaml` recipients if needed.

2. ArgoCD repository secret
- Template: `secrets/templates/argocd-repository-secret.example.yaml`
- Namespace/Secret: `argocd/homelab-k8s-repo`
- Where to get values:
  - GitHub PAT or GitHub App credentials for repo read access.

3. Tailscale operator OAuth
- SOPS file in use: `operators/tailscale-operator/base/operator-oauth-secret.sops.yaml`
- Namespace/Secret: `tailscale/operator-oauth`
- Where to get values:
  - Tailscale admin console -> Settings -> OAuth clients
  - scopes: `devices`, `auth_keys`, `services`
- Required policy:
  - tailnet ACL must allow requested tags.
  - see `terraform/tailscale` in `homelab-k8s` for policy pattern.

4. Cloudflare API token for external-dns
- SOPS file in use: `infrastructure/external-dns/overlays/erauner-cloud/secret.external-dns-cloudflare.sops.yaml`
- Namespace/Secret: `network/external-dns-cloudflare-secret`
- Where to get values:
  - Cloudflare dashboard -> My Profile -> API Tokens
  - token needs DNS edit permission for your zone.

5. Cloudflared tunnel token
- SOPS file in use: `infrastructure/cloudflared-apps/overlays/erauner-cloud/secret.cloudflared-apps-token.sops.yaml`
- Namespace/Secret: `network/cloudflared-apps-token`
- Where to get values:
  - Cloudflare Zero Trust -> Networks -> Tunnels -> your tunnel -> token.

## Domain and hostname values to replace

Replace `erauner.cloud` with your domain in:
- `apps/poc-exposure-patterns/base/httproute-public.yaml`
- `infrastructure/external-dns/overlays/erauner-cloud/values.yaml`
- `operators/envoy-gateway/overlays/erauner-cloud/gateway-public.yaml`

## Safe replacement workflow

1. Generate your age key.
2. Replace `sops-age` seed file.
3. Re-encrypt SOPS files with your recipient.
4. Replace Tailscale and Cloudflare secret values.
5. Commit and let ArgoCD sync.

## Validation commands

```bash
kubectl -n argocd get secret sops-age
kubectl -n tailscale get secret operator-oauth
kubectl -n network get secret external-dns-cloudflare-secret
kubectl -n network get secret cloudflared-apps-token
kubectl -n argocd get applications.argoproj.io
```

## Before sharing with cousin

- Ensure no owner credentials remain.
- Rotate all temporary/test credentials used during bootstrap.
- Confirm DNS hostnames point to cousin domain and not `erauner.cloud`.
