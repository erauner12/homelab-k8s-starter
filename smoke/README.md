# Smoke checks

This directory defines profile-specific smoke checks for ArgoCD and workload readiness.

Files:
- `checks-minimal.yaml`: smallest common baseline
- `checks-argocd.yaml`: ArgoCD synchronization gates
- `checks-cloud.yaml`: cloud profile smoke gates
- `checks-local.yaml`: local Talos profile smoke gates
- `checks.yaml`: default check set (currently cloud)
- `scripts/common.sh`: shared smoke helpers
- `scripts/run.sh`: smoke runner

Usage:

```bash
# Auto-detect profile (cloud kubeconfig path -> cloud, otherwise local)
./smoke/scripts/run.sh

# Explicit profile
./smoke/scripts/run.sh --profile cloud
./smoke/scripts/run.sh --profile local --context starter-talos

# Explicit checks file
./smoke/scripts/run.sh --checks smoke/checks-minimal.yaml
```

Environment:
- `APP_TIMEOUT_SECONDS` (default `600`)
- `POD_TIMEOUT_SECONDS` (default `300`)
- `POLL_SECONDS` (default `5`)
- `SMOKE_COMMON_NETWORKING` (default `auto`)
  - `auto`: run shared Cloudflare/Tailscale networking gates only when required secrets are present
  - `always`: always run shared networking gates
  - `never`: skip shared networking gates
