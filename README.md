# Homelab Kubernetes Starter (ArgoCD Only)

A minimal, shareable GitOps starter for a single-node homelab Kubernetes cluster.

This repository intentionally uses ArgoCD only.

## Included baseline
- ArgoCD app-of-apps bootstrap
- cert-manager
- external-secrets
- tailscale-operator
- external-dns
- longhorn day-2 configuration
- security namespace and policy baseline
- demo app

## Quick start
1. Fork this repository.
2. Clone your fork.
3. Update starter placeholders (repo URL, domain, secrets).
4. Run preflight checks:
   - `./scripts/pre-bootstrap-test.sh`
5. Bootstrap:
   - `./bin/homelabctl bootstrap plan`
   - `./bin/homelabctl bootstrap run --kubeconfig ~/.kube/config`

## Notes
- Keep secret files as templates only in Git.
- Generate your own credentials and tokens per environment.
