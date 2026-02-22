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
1. Run static validation first:
   - `./scripts/static-validate.sh`
2. Create kind cluster and deploy starter profile:
   - `./scripts/kind-up.sh`
3. Check status:
   - `./scripts/kind-status.sh`
4. Run validation gates:
   - `./scripts/kind-validate.sh`
5. Tear down:
   - `./scripts/kind-down.sh`

See `docs/KIND.md` for details.

Note: Helm-backed static checks require Helm 3.

## Continuous validation
This repository includes a GitHub Actions workflow that runs the same smoke gate on `pull_request` and `push` to `main`:
- `.github/workflows/kind-validate.yml`

Workflow sequence:
1. `./scripts/static-validate.sh`
2. `./scripts/kind-up.sh`
3. `./scripts/kind-validate.sh`
4. `./scripts/kind-status.sh` (on failure)
5. `./scripts/kind-down.sh` (always)

## Cloud/bootstrap workflow
Use the cluster app-of-apps manifests under `clusters/` and configure repository credentials and secrets from `docs/SECRETS.md`.

## Notes
- Keep secret files as templates only in Git.
- Generate your own credentials and tokens per environment.
