# Homelab Kubernetes GitOps

A production-ready GitOps configuration for a Kubernetes homelab using Flux, Kyverno, and best practices for policy-driven infrastructure.

## 🏗️ Architecture

This repository implements a hardened GitOps workflow with:

- **Flux v2** for GitOps automation
- **Kyverno** for policy enforcement with mutation + validation
- **Traefik** for ingress with BGP LoadBalancer support
- **Cilium** for networking and load balancing
- **CloudNative-PG** for PostgreSQL databases
- **SOPS** for secret encryption
- **External-DNS** for automatic DNS management
- **homelabctl** for static validation and GitOps quality assurance

## 🔍 Validation Framework

The repository includes a comprehensive validation framework via the `homelabctl` CLI tool:

- **Layer Taxonomy Validation** - Ensures resources are in the correct GitOps layer (infra/stack/policy)
- **Manifest Validation** - YAML syntax, Kustomize builds, and Kubernetes schema validation
- **Pre-commit Integration** - Automatic validation on every commit
- **CI/CD Ready** - JSON output for tooling integration

```bash
# Quick validation
task validate:layers
task validate:manifests

# Or build and use directly
go build -o bin/homelabctl ./cmd/homelabctl
homelabctl validate layers .
```

See [docs/VALIDATION.md](docs/VALIDATION.md) for complete usage guide.

## 🚀 Quick Start

### Prerequisites

- Kubernetes cluster (v1.28+)
- Flux CLI
- SOPS with age encryption
- Kustomize v5+
- Kyverno CLI (for testing)

### Bootstrap

**🎯 Automated Bootstrap (Recommended)**

Use the new `homelabctl bootstrap` engine for reliable, idempotent setup:

```bash
# Build the CLI
task build-cli

# Plan what will be executed (dry-run)
./bin/homelabctl bootstrap plan

# Run the complete bootstrap
./bin/homelabctl bootstrap run
```

See **[📖 Bootstrap Engine Guide](docs/BOOTSTRAP_ENGINE.md)** for complete usage.

**📚 Manual Bootstrap (Advanced)**

For custom environments or learning purposes:

1. **Clone and configure**:
   ```bash
   git clone https://github.com/yourusername/homelab-k8s
   cd homelab-k8s
   ```

2. **Install Flux**:
   ```bash
   flux bootstrap github \
     --owner=yourusername \
     --repository=homelab-k8s \
     --branch=master \
     --path=clusters/home/flux
   ```

3. **Configure SOPS** (see [SOPS Setup](#sops-setup))

4. **Verify deployment**:
   ```bash
   ./scripts/reconcile.sh
   ```

See **[📖 Manual Bootstrap Guide](docs/BOOTSTRAP.md)** for detailed procedures.

## 📁 Repository Structure

```
homelab-k8s/
├── apps/                           # Application definitions
│   ├── gitea/                     # Git hosting
│   ├── homepage/                  # Dashboard
│   └── vikunja/                   # Task management
├── clusters/                      # Cluster-specific configuration
│   └── home/
│       ├── apps/                  # Application deployments
│       └── flux/                  # Flux configuration
├── components/                    # Reusable Kustomize components
│   └── service-loadbalancer/      # BGP LoadBalancer component
├── infrastructure/               # Platform infrastructure
│   ├── base/                     # Base infrastructure
│   └── home/                     # Home cluster specifics
├── scripts/                      # Automation scripts
└── tests/                        # Policy and integration tests
```

## 🔗 Related Repositories

Components that have been decoupled into separate repositories for independent versioning and reuse:

| Repository | Description | Used By |
|------------|-------------|---------|
| [homelab-jenkins-library](https://github.com/erauner12/homelab-jenkins-library) | Jenkins shared library with reusable pipeline components (`@Library('homelab')`) | Jenkins CI pipelines |
| [homelab-shadow](https://github.com/erauner12/homelab-shadow) | GitOps validation CLI for ArgoCD multi-cluster deployments | CI validation, shadow sync |
| [homelab-go-utils](https://github.com/erauner12/homelab-go-utils) | Shared Go utilities (formatting, health checks, k8s helpers) | Go tools in this ecosystem |
| [homelab-validation-image](https://github.com/erauner12/homelab-validation-image) | Container image bundling CI validation tools (kustomize, helm, kubeconform, kyverno) | Jenkins CI pods |
| [homelab-smoke](https://github.com/erauner12/homelab-smoke) | Declarative smoke test framework for cluster health validation | Cluster health checks |
| [homelab-manifest-service](https://github.com/erauner12/homelab-manifest-service) | API service tracking component versions (Go modules, Docker images, Helm charts) | Backstage integration |
| [backstage-plugins](https://github.com/erauner12/backstage-plugins) | Custom Backstage plugins and app configuration | Developer portal |
| [homelab-k8s-shadow](https://github.com/erauner12/homelab-k8s-shadow) | Rendered manifests for PR diff previews | Shadow sync output |
| [omni](https://github.com/erauner12/omni) | Talos/Omni cluster configuration | Cluster provisioning |

### Local Development Setup

For cross-repo development, configure local paths:

```bash
# Copy and customize paths
cp .env.example .env

# Verify all repos are cloned
./scripts/check-repos.sh
```

The `.env` file configures paths to related repositories (default: `~/git/side/`). Scripts use these paths for cross-repo operations.

## 🛡️ Policy Framework

### Hardened Approach

This configuration uses a **"mutate → validate"** policy approach that:

1. **Automatically fixes** common misconfigurations
2. **Validates** critical security requirements
3. **Prevents** infinite retry loops during bootstrapping

### Key Policies

| Policy | Purpose | Action |
|--------|---------|--------|
| `require-lb-pool` | BGP pool assignment | Mutate + Validate |
| `enforce-lb-local` | External traffic policy | Validate |
| `enforce-managed-namespace` | Namespace governance | Validate |
| `require-homepage-annotations` | Service discovery | Validate |

### Golden Path: LoadBalancer Services

Creating BGP-enabled LoadBalancer services is now effortless:

```yaml
# Method 1: Use the component (recommended)
components:
  - ../../../../kustomize/components/service-loadbalancer

# Method 2: Label-based auto-promotion
metadata:
  labels:
    homelab.dev/expose-loadbalancer: "true"
```

See [BGP Documentation](docs/networking/BGP.md) for details.

## 🔄 GitOps Workflow

### Dependency Layers

The deployment follows strict dependency ordering:

1. **Infrastructure** (`infra`) - Controllers, networking, policies
2. **Stacks** (`stack`) - Complete application stacks with databases
3. **Policies** (`policy`) - Validation rules applied after resources exist

### Reconciliation

Use the enhanced reconciliation script:

```bash
# Reconcile everything in dependency order
./scripts/reconcile.sh

# Reconcile specific components
./scripts/reconcile.sh home-infra-controllers home-infra-configs

# Verbose mode for troubleshooting
./scripts/reconcile.sh --verbose
```

## 🛠️ Development Workflow

### Pre-commit Validation

The repository includes comprehensive pre-commit checks:

```bash
# Install pre-commit hooks
pre-commit install

# Run manually
./scripts/pre-commit-comprehensive.sh
```

Validates:
- Kustomize builds
- Kyverno policies
- SOPS encryption
- Flux CRDs
- Policy compliance

### Testing Policies

```bash
# Run all Kyverno tests
kyverno test infrastructure/base/kyverno-policies/tests/native --detailed-results

# Test specific policy
kyverno test infrastructure/base/kyverno-policies/tests/native/require-lb-pool
```

### Adding New Applications

1. **Create base manifests** in `apps/<name>/base/`
2. **Add overlays** for environment-specific config
3. **Create stack** in `apps/<name>/stack/production/`
4. **Add Flux Kustomization** in `clusters/home/flux/`

Example structure:
```
apps/myapp/
├── base/
│   ├── helmrelease.yaml
│   └── kustomization.yaml
├── overlays/
│   └── production/
│       ├── kustomization.yaml
│       └── ingress.yaml
└── stack/
    └── production/
        └── kustomization.yaml
```

## 🔐 Security

### SOPS Setup

1. **Generate age key**:
   ```bash
   age-keygen -o ~/.config/sops/age/keys.txt
   ```

2. **Configure `.sops.yaml`**:
   ```yaml
   keys:
     - &home age1xxx...
   creation_rules:
     - path_regex: .*\.sops\.yaml$
       age: *home
   ```

3. **Encrypt secrets**:
   ```bash
   sops -e secret.yaml > secret.sops.yaml
   ```

### Policy Exceptions

Emergency escape hatch for blocked deployments:

```bash
kubectl apply -f - <<EOF
apiVersion: kyverno.io/v1alpha2
kind: PolicyException
metadata:
  name: emergency-exception
  namespace: myapp
spec:
  policies: [require-lb-pool]
  match:
    any:
      - resources:
          kinds: ["Service"]
          names: ["myservice"]
  duration: 30m
EOF
```

## 🌐 Networking

### BGP LoadBalancer

Services are automatically configured for BGP advertisement:

- **Pool 10**: Infrastructure (default)
- **Pool 20**: Collaboration tools
- **Pool 40**: Dashboards and monitoring

### DNS Integration

External-DNS automatically manages DNS records:

- **Cloudflare**: for public domains
- **Tunnel**: for internal access via Cloudflare Tunnel

## 📊 Monitoring

### Health Checks

```bash
# Check all Flux resources
flux get all -A

# Check Kyverno policies
kubectl get clusterpolicy

# Check BGP status
kubectl exec -n kube-system cilium-xxx -- cilium bgp routes
```

### Common Issues

See [Troubleshooting Guide](docs/troubleshooting.md) for common issues and solutions.

## 🤝 Contributing

1. **Fork** the repository
2. **Create** a feature branch
3. **Test** with pre-commit hooks
4. **Submit** a pull request

### Code Style

- Use **Kustomize components** for reusable patterns
- Follow **GitOps principles** - everything as code
- **Document** policy decisions and architectural choices
- **Test** changes with Kyverno CLI before committing

## 📚 Documentation

- [BGP LoadBalancer Guide](docs/networking/BGP.md)
- [Policy Framework](docs/policies/README.md)
- [Troubleshooting](docs/troubleshooting.md)
- [Architecture Decisions](docs/adr/)

## 🔄 Maintenance

### Regular Tasks

- **Update** Helm chart versions
- **Rotate** secrets annually
- **Review** policy violations
- **Test** disaster recovery procedures

### Backup Strategy

- **Git**: Source of truth for configuration
- **Velero**: For persistent volume backups
- **Database**: PostgreSQL continuous archiving

## 📄 License

MIT License - see [LICENSE](LICENSE) for details.

---

**🏠 Homelab GitOps** - *Making Kubernetes management effortless through policy-driven automation*


## Run

from: https://github.com/erauner/homelab-k8s


ssh key:
```
eval $(ssh-agent -s) && ssh-add ~/.ssh/id_ed25519 && SSH_AUTH_SOCK=$SSH_AUTH_SOCK SSH_AGENT_PID=$SSH_AGENT_PID task test:e2e:bootstrap
```

deploy key:

```
TBD
```
