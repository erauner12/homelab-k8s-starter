# httproute-public component

Purpose: reusable public HTTPRoute baseline for Envoy Gateway + Cloudflare DNS annotation pattern.

Defaults:
- route name: `app-public`
- hostname: `app.example.com`
- DNS target: `tunnel.example.com`
- backend: `app:80`
- parent gateway: `network/envoy-public`

Consumers should patch name, hostnames, DNS annotations, and backend service/port.
