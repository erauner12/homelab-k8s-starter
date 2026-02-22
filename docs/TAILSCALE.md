# Tailscale Operator

The cloud operators profile includes the Tailscale operator app. It will sync successfully after OAuth credentials are configured.

## 1. Create OAuth secret

Template:
- `secrets/templates/tailscale-operator-oauth-secret.sops.example.yaml`

Apply a Secret named `operator-oauth` in namespace `tailscale` (keys: `client_id`, `client_secret`).

For local testing, you can decrypt and apply from your private repo copy:
```bash
sops -d /path/to/operator-oauth-secret.sops.yaml | kubectl apply -f -
```

## 2. Cloud operators include this app

Defined in:
- `clusters/cloud/argocd/operators/kustomization.yaml`
- `clusters/cloud/argocd/operators/tailscale-operator-app.yaml`

## 3. Verify

- `kubectl -n tailscale get pods`
- `kubectl -n argocd get application tailscale-operator`

## 4. Optional hardening (tags)

Starter defaults to untagged operator/proxy behavior to avoid ACL coupling.

If you want tag-based policy, set tags in:
- `operators/tailscale-operator/base/values/values.yaml`

Then configure matching `tagOwners` in your Tailscale ACL so the OAuth client is allowed to request those tags.
