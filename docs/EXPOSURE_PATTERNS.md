# Exposure Patterns (Cloudflare and Tailscale)

This starter now includes a minimal app-level example that mirrors your OpenClaw/Gatus approach:
- Cloudflare tunnel DNS via HTTPRoute annotations
- Tailscale access via Ingress class `tailscale`

Example path:
- `apps/poc-exposure-patterns/base`

Resources included:
- `deployment.yaml` + `service.yaml`
- `httproute-public.yaml` (External-DNS/Cloudflare pattern)
- `ingress-tailscale.yaml` (Tailscale pattern)

## How it maps to your existing pattern

Cloudflare DNS route pattern:
- `external-dns.alpha.kubernetes.io/hostname`
- `external-dns.alpha.kubernetes.io/target: tunnel.<zone>`
- `external-dns.alpha.kubernetes.io/cloudflare-proxied: "true"`
- `parentRefs` to `envoy-public` in `network` namespace

Tailscale route pattern:
- `ingressClassName: tailscale`
- `tailscale.com/proxy-class: "iptables-proxy"`
- TLS hostname entry in Ingress spec

## Deploy for testing
The Argo app manifest is provided as optional:
- `clusters/cloud/argocd/apps/exposure-demo-app.yaml`
- `clusters/cloud/argocd/apps/kustomization.optional.yaml`

Apply it with:
```bash
kubectl apply -k clusters/cloud/argocd/apps/kustomization.optional.yaml
```

## Notes
- Replace `exposure-demo.erauner.cloud` for non-test domains.
- If Tailscale operator is not enabled, the Ingress still applies but will not be reconciled by a controller.
