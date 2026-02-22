# Homelab Kubernetes Starter (ArgoCD Only)

A minimal, shareable GitOps starter for homelab Kubernetes clusters.

This repository intentionally uses ArgoCD only.

## Included baseline
- ArgoCD app-of-apps bootstrap manifests
- cert-manager
- external-secrets
- security namespace baseline
- demo app
- local kind smoke-test profile
- optional Rackspace Spot Terraform pattern

## Local test workflow (recommended first)
1. Create kind cluster and deploy starter profile:
   - `./scripts/kind-up.sh`
2. Check status:
   - `./scripts/kind-status.sh`
3. Tear down:
   - `./scripts/kind-down.sh`

See `docs/KIND.md` for details.

## Cloud/bootstrap workflow
Use the cluster app-of-apps manifests under `clusters/` and configure repository credentials and secrets from `docs/SECRETS.md`.

## Notes
- Keep secret files as templates only in Git.
- Generate your own credentials and tokens per environment.
