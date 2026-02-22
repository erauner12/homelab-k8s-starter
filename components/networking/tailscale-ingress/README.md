# tailscale-ingress component

Purpose: reusable Tailscale ingress baseline for internal-only app exposure.

Defaults:
- `Ingress` name: `app-tailscale`
- backend service: `app:80`
- TLS host: `app`
- annotation: `tailscale.com/proxy-class=iptables-proxy`

Consumers should patch name, backend service/port, and host.

Usage:

```yaml
components:
  - ../../../components/networking/tailscale-ingress
patches:
  - target:
      kind: Ingress
      name: app-tailscale
    patch: |-
      - op: replace
        path: /metadata/name
        value: myapp-tailscale
```
