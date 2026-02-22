# Homelab Kubernetes Starter (ArgoCD Only)

A minimal, shareable GitOps starter for homelab Kubernetes clusters.

This repository intentionally uses ArgoCD only.

## Included baseline
- ArgoCD app-of-apps bootstrap manifests
- cert-manager
- external-secrets
- envoy-gateway (cloud profile)
- security namespace baseline
- demo app
- local Talos smoke-test profile
- optional Rackspace Spot Terraform pattern

Optional operators:
- cloudflared-apps (requires Cloudflare tunnel token setup)
- tailscale-operator (requires OAuth secret setup)

## Local test workflow (recommended first)
1. Run static validation first (auto-selects full if Helm 3 is available):
   - `./scripts/static-validate.sh`
   - Optional explicit modes:
   - `./scripts/static-validate-fast.sh`
   - `./scripts/static-validate-full.sh`
2. Create local Talos cluster and deploy starter profile:
   - `./scripts/talos/local-up.sh`
3. Check status:
   - `./scripts/talos/local-status.sh`
4. Run smoke validation:
   - `./scripts/talos/local-validate.sh`
   - Or directly: `./smoke/scripts/run.sh --profile local --context starter-talos`
5. Tear down:
   - `./scripts/talos/local-down.sh`

Note: full static validation requires Helm 3.

## Continuous validation
This repository includes a GitHub Actions workflow that runs the same smoke gate on `pull_request` and `push` to `main`:
- `.github/workflows/local-validate.yml`

Workflow sequence:
1. `./scripts/static-validate-full.sh`
2. `./scripts/talos/local-up.sh`
3. `./scripts/talos/local-validate.sh`
4. `./scripts/talos/local-status.sh` (on failure)
5. `./scripts/talos/local-down.sh` (always)

## Cloud/bootstrap workflow
Use the cluster app-of-apps manifests under `clusters/` and configure repository credentials and secrets from `docs/SECRETS.md` and `docs/CREDENTIALS_SETUP.md`.

Repeatable cloud e2e bootstrap:
- `task cloud:e2e` keeps cluster running for manual validation
- `task cloud:e2e:destroy` destroys cluster automatically at script exit
- Shared smoke checks are run with `./smoke/scripts/run.sh --profile cloud` during cloud e2e

Operator notes:
- Envoy Gateway is enabled in the cloud operators profile.
- Cloudflared apps tunnel is staged as optional. See `docs/CLOUDFLARE.md`.
- Tailscale operator is enabled in cloud operators; provide OAuth secret first. See `docs/TAILSCALE.md`.
- App exposure examples (Cloudflare + Tailscale) are in `docs/EXPOSURE_PATTERNS.md`.

## Notes
- Keep secret files as templates only in Git.
- Generate your own credentials and tokens per environment.
- OpenClaw-specific helper scripts live under `scripts/openclaw/`.
- Talos standalone baseline lives under `talos/` (see `docs/TALOS_FROM_OMNI.md`).
