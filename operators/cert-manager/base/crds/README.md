# cert-manager CRDs

These CRDs were copied from the official cert-manager release:
https://github.com/cert-manager/cert-manager/releases/tag/v1.17.1

## Updating CRDs

When bumping the Helm chart version in `../helmrelease.yaml`:

1. Download the new CRD manifests from the corresponding release
2. Replace all `*.yaml` files in this directory
3. Update this README with the new version
4. Test in a development environment before promoting

## Current Version
- cert-manager: v1.17.1
- Last updated: 2025-06-28

## CRD Files
- infrastructure/base/cert-manager/crds/cert-manager.crds.yaml

## ClusterIssuer Configuration

**Important**: When creating Certificate resources that reference our Cloudflare ClusterIssuer, use `key: token` (not `api-token`):

```yaml
apiVersion: cert-manager.io/v1
kind: Certificate
metadata:
  name: example-cert
  namespace: default
spec:
  secretName: example-cert-tls
  dnsNames:
    - example.erauner.dev
  issuerRef:
    name: letsencrypt-cloudflare-home
    kind: ClusterIssuer
    # ↑ This references the secret with key: token
```

The ClusterIssuer is configured to use:
- Secret: `cloudflare-api-token-home`
- Key: `token`
