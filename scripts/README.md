# Scripts

This directory contains helper scripts for diagnostics, daily operations, and GitOps validation.

## Quick Reference

- **🔧 Pre-commit**: See [docs/pre-commit/README.md](../docs/pre-commit/README.md) for modern validation system
- **🔧 Git Hooks (Legacy)**: `install-hooks.sh` - Legacy pre-commit installation (deprecated)
- **🔍 Validation**: `validate-gitops.sh` - Check GitOps resource management
- **📊 Drift Detection**: `check-drift.sh` - Detect configuration drift
- **🧪 CloudNative-PG Testing**: `test-cnpg.sh` - Integration test for PostgreSQL operator
- **🛰️ Server-side Validation**: `task kustomize:dry-run` - API compatibility testing
- **🌐 Networking**: `hlnet.sh` - Unified networking and GitOps CLI
- **🚀 Gitea Smoke Test**: `gitea-smoke-test.sh` - Validate Gitea external and VIP access
- **🔒 BGP Policy Guards**:
  - `check-loadbalancer-policy.sh` - Prevent LoadBalancer BGP regressions
  - `../hack/check-lbs.sh` - Validate all LB services use `externalTrafficPolicy: Local`
- **🚀 Helm Operations**:
  - `force-helm-cleanup.sh` - Force cleanup stuck Helm releases with Flux/Kyverno integration
  - `helm-nuke.sh` - Quick alias for force cleanup

## Pre-commit Validation

### Modern Pre-commit Framework (Recommended)
```bash
# Install and setup (one time)
pip install pre-commit
pre-commit install

# Validate all files
pre-commit run --all-files

# Automatic validation on git commit
git commit -m "Your message"  # Hooks run automatically
```

See [docs/pre-commit/README.md](../docs/pre-commit/README.md) for comprehensive documentation.

### Legacy Git Hooks (Deprecated)

#### `install-hooks.sh`
Legacy pre-commit hook installation:

```bash
./scripts/install-hooks.sh  # Install legacy hooks (deprecated)
git commit --no-verify     # Bypass hooks (emergency use)
```

> **Note**: This script is deprecated. Use the modern pre-commit framework instead.

## GitOps Validation

### `validate-gitops.sh`
Comprehensive validation of GitOps resources:

```bash
./scripts/validate-gitops.sh  # Check all critical resources are managed by Flux
```

### `check-drift.sh`
Detects configuration drift in Flux kustomizations:

```bash
./scripts/check-drift.sh  # Check for drift in deployed resources
```

### `check-loadbalancer-policy.sh`
BGP LoadBalancer policy validation to prevent regressions:

```bash
# Run manually to check all LoadBalancer services
./scripts/check-loadbalancer-policy.sh

# Skip in CI if cluster is unavailable
SKIP_BGP_POLICY_CHECK=1 git commit
```

## Additional Guards (`../hack/`)

### `check-lbs.sh`
Complementary guard that validates ALL LoadBalancer services have the correct traffic policy:

```bash
# Check all LoadBalancer services for BGP compliance
../hack/check-lbs.sh

# Available as Task command
task lint:loadbalancer-policy

# Skip in pre-commit if cluster is unavailable
SKIP_LB_POLICY_CHECK=1 git commit
```

This guard ensures no LoadBalancer services can be deployed without `externalTrafficPolicy: Local`, which is critical for BGP advertisement and traffic routing.

This guard ensures all LoadBalancer services use `externalTrafficPolicy: Local` for proper BGP/Cilium VIP advertisement. Prevents TLS connection resets and ensures VIPs are only advertised from nodes with healthy pods. Automatically runs during pre-commit validation when cluster is accessible.

See [Git Hooks Documentation](../docs/git-hooks.md) for detailed usage.

## Helm Operations

### `force-helm-cleanup.sh`
Comprehensive script for forcefully cleaning up stuck Helm releases while managing FluxCD and Kyverno integrations:

```bash
# Full cleanup with Flux Kustomization suspension
./scripts/force-helm-cleanup.sh homepage homepage -k home-homepage-stack

# Cleanup and immediately pull latest Git changes + redeploy
./scripts/force-helm-cleanup.sh homepage homepage -k home-homepage-stack --git-pull

# Only suspend Flux temporarily (for manual changes)
./scripts/force-helm-cleanup.sh homepage homepage -k home-homepage-stack --suspend-only

# Resume Flux after manual changes
./scripts/force-helm-cleanup.sh homepage homepage -k home-homepage-stack --resume-only

# Resume with latest Git changes (perfect for quick iterations)
./scripts/force-helm-cleanup.sh homepage homepage -k home-homepage-stack --resume-only --git-pull

# Force cleanup without confirmation prompts
./scripts/force-helm-cleanup.sh homepage homepage -k home-homepage-stack --force
```

This script safely handles:
- **Flux Integration**: Temporarily suspends Kustomization reconciliation to prevent conflicts
- **Git Source Refresh**: Optionally forces Git repository sync to pull latest changes before deployment
- **Kyverno Policies**: Sets enforcement to audit mode during cleanup, then restores
- **HelmRelease Cleanup**: Force-deletes stuck HelmRelease resources and finalizers
- **Helm Secrets**: Cleans up orphaned Helm secrets that can cause deployment issues
- **Associated Resources**: Optionally removes related Kubernetes resources
- **State Restoration**: Automatically restores Kyverno policies, with manual or automatic Flux resume

Perfect for resolving stuck deployments, policy conflicts, and resource finalization issues.

### `helm-nuke.sh`
Quick alias for force cleanup operations:

```bash
# Quick cleanup with automatic force flag
./scripts/helm-nuke.sh homepage homepage home-homepage-stack

# Quick cleanup with latest Git changes
./scripts/helm-nuke.sh homepage homepage home-homepage-stack --git-pull

# Minimal usage (no Kustomization specified)
./scripts/helm-nuke.sh vikunja vikunja
```

Designed for rapid troubleshooting when you need to quickly reset a deployment state.

## Testing and Integration

### `gitea-smoke-test.sh`
Comprehensive smoke test for Gitea service health, validating both internal VIP and external public URL access:

```bash
# Run full smoke test with defaults
./scripts/gitea-smoke-test.sh

# Test with custom VIP or timeout
./scripts/gitea-smoke-test.sh --vip 10.10.0.2 --timeout 30

# Show help and available options
./scripts/gitea-smoke-test.sh --help
```

This test validates:
- VIP access via BGP LoadBalancer (both HTTP and HTTPS)
- Public URL access via Cloudflare Tunnel
- HTTP→HTTPS redirect functionality
- BGP advertisement and `externalTrafficPolicy` configuration
- Gitea login page accessibility

Perfect for CI/CD pipelines, monitoring, and post-deployment validation.

### `test-cnpg.sh`
Comprehensive integration test for CloudNative-PG operator using kind cluster:

```bash
# Run test and leave cluster for inspection
./scripts/test-cnpg.sh

# Run test and cleanup afterwards
CLEANUP_CLUSTER=true ./scripts/test-cnpg.sh

# Show help
./scripts/test-cnpg.sh --help
```

This test validates:
- CloudNative-PG operator deployment via Flux
- PostgreSQL cluster creation and health
- Database connectivity and SQL operations
- All CRDs and resources are properly installed

See [CloudNative-PG Testing Documentation](../test/cloudnative-pg/README.md) for detailed information.

## `hlnet.sh` - The main entry-point

`hlnet.sh` is a unified command-line interface for all networking and GitOps tools. It discovers and registers commands from the `*-net-tools.sh` library files.

### Quick start

Run `hlnet.sh` with `help` to see all available commands:

```bash
./scripts/hlnet.sh help
```

**Examples:**

```bash
# Get a full snapshot of the Cloudflare Tunnel and related DNS.
./scripts/hlnet.sh net_tunnel_snapshot

# Check BGP status on the default control-plane node.
./scripts/hlnet.sh bgp_peers

# Check BGP status on a specific worker node.
./scripts/hlnet.sh bgp_peers worker2

# Check the status of a HelmRelease.
./scripts/hlnet.sh hr_status -n network envoy-gateway

# Bootstrap Flux GitOps for home environment
./scripts/hlnet.sh flux_bootstrap_all home master

# Check Flux status overview
./scripts/hlnet.sh flux_status_overview
```

### Flux bootstrap helpers

| Command | What it does |
|---------|--------------|
| `hlnet flux_check_prerequisites` | Verify all tools and keys are ready |
| `hlnet flux_bootstrap_prepare <env>` | Creates AGE & Git secrets |
| `hlnet flux_bootstrap_git <env> [branch]` | Runs `flux install` and `flux bootstrap git …` |
| `hlnet flux_bootstrap_all <env> [branch]` | One‑shot: prepare → bootstrap → status |
| `hlnet flux_status_overview` | Quick "what's synced / what's failing" |
| `hlnet flux_uninstall` | Completely remove Flux from cluster |

### Adding new commands

To add a new command, simply add a function to one of the `*-net-tools.sh` files and register it using the `hl::register` function from `lib/common.sh`. The `hlnet.sh` script will automatically pick it up.

## Monitoring and Alerting

The `gitea-smoke-test.sh` script is designed for continuous monitoring and can be:
- **Scheduled in CI/CD**: Automated GitHub Actions workflow runs every 10 minutes
- **Integrated with monitoring**: Wrap with Prometheus pushgateway or blackbox_exporter
- **Used for debugging**: Manual execution during troubleshooting

This provides early warning if BGP LoadBalancer settings are accidentally changed or if tunnel connectivity is broken.

## Day-2 Operations and Backlog

The following items enhance operational excellence and can be implemented during future maintenance windows:

### Observability Enhancements
- **BGP Health Monitoring**: Add Grafana panel on `cilium_bgp_advertised_prefixes_total{service="envoy-gateway"}` with alert if < 2 for > 2 minutes
- **Slack Integration**: Configure failure-only notifications from smoke test CI to reduce noise
- **CNPG Metrics**: Monitor replica lag and backup health via built-in Prometheus metrics

### Operational Procedures
- **Runbook Creation**: Document procedures for node cordoning, credential rotation, CNPG recovery
- **Backup Validation**: Monthly chaos restore drills into temporary namespace
- **Certificate Management**: Review Let's Encrypt DNS-01 vs cert-manager HTTP-01 strategy

### Future-Proofing
- **Gateway-API Enhancement**: Track Envoy Gateway features and `externalTrafficPolicy` semantics
- **Automated Backups**: Verify `pgbackrest` schedules and object storage lifecycle

### Weekly Health Checks
| Component | Check | Tool |
|-----------|-------|------|
| Smoke Tests | GitHub Actions status | GitHub → Actions |
| Pod Health | Restart counts, resource usage | `kubectl get po -n network -o wide` |
| BGP Status | VIP advertisements per service | Cilium metrics dashboard |
| Database | CNPG replica lag, backup sizes | CNPG Prometheus metrics |

See the comprehensive [BGP LoadBalancer Documentation](../docs/networking/BGP.md) for troubleshooting BGP-related issues.
