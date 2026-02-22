# Security Directory

This directory contains **access control and security governance** resources for the homelab Kubernetes cluster.

## Architectural Decision: `security/` vs `policies/`

This repository deliberately separates two concerns that are often conflated:

| Directory | Purpose | Future Repo |
|-----------|---------|-------------|
| `security/` | **Access Control** - Who can access what | `deployment-security` |
| `policies/` | **Admission Control** - What resources are valid | `deployment-validation` |

### `security/` - Access Control (this directory)

Controls **who can access what** in the cluster:

- **Namespaces** - Access control boundaries and resource isolation
- **RBAC** - Role-based access control for humans and service accounts
- **Network Policies** - Network-level access control between workloads
- **Resource Quotas** - Resource limits per namespace/team
- **ArgoCD Projects** - Application deployment boundaries

Think of this as: "Can this user/workload access this resource?"

### `policies/` - Admission Control (separate directory)

Controls **what resources are valid** in the cluster:

- **Kyverno Policies** - Mutation and validation of resources
- **ValidatingAdmissionPolicies** - CEL-based admission control
- **Policy Exceptions** - Exemptions for specific workloads

Think of this as: "Is this resource configuration allowed?"

### Why This Separation?

1. **Different lifecycles** - Access control changes when teams/apps change; admission policies change when security requirements change

2. **Different owners** - Platform team owns access control; security team owns admission policies

3. **Repo splitting readiness** - Each can be extracted to its own repository:
   - `deployment-security` - Access control, namespaces, RBAC
   - `deployment-validation` - Admission policies, compliance rules

4. **Cleaner mental model** - "Who can access" vs "What is valid" are orthogonal concerns

## Directory Structure

```
security/
├── namespaces/           # Security-layer namespaces (auth, security, external-secrets)
│   ├── base/
│   │   └── _system/      # System namespace definitions
│   └── overlays/
│       └── home/
├── rbac/                 # Platform/team RBAC (not app-specific)
│   ├── base/
│   │   └── gateway-api/  # Gateway API access control
│   └── overlays/
│       └── home/
├── network-policies/     # Security-layer network policies
│   ├── base/
│   │   ├── auth/         # Dex policies
│   │   ├── external-secrets/
│   │   └── security/     # 1Password Connect policies
│   └── overlays/
│       └── home/
├── resource-quotas/      # Namespace resource limits (future)
│   ├── base/
│   └── overlays/
│       └── home/
└── argocd/               # ArgoCD AppProjects (future)
    ├── base/
    │   └── projects/
    └── overlays/
        └── home/
```

## Overlay Structure

Security uses **cluster-based** overlay naming:

| Overlay | Purpose |
|---------|---------|
| `overlays/erauner-home/` | Home cluster (192.168.x.x) configuration |

### Current Pattern

```
security/namespaces/overlays/
└── erauner-home/            # ← Cluster name (not environment)
    └── kustomization.yaml
```

Security resources are cluster-level and don't vary between environments (production/staging) - namespace definitions, RBAC, and network policies apply to the entire cluster.

### Kustomization Example

```yaml
# security/namespaces/overlays/erauner-home/kustomization.yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

resources:
  - ../../base

# Cluster-specific namespace additions (if needed)
```

### Future: Multi-Cluster Support

See [Issue #1256](https://github.com/erauner12/homelab-k8s/issues/1256) for multi-cluster patterns.

Adding a new cluster only requires:

```bash
cp -r security/<component>/overlays/erauner-home security/<component>/overlays/erauner-cloud
# Customize for cloud cluster (different namespaces, RBAC, etc.)
```

## What Stays With Applications

Not everything security-related belongs here. **Application-specific** security resources stay with their apps:

| Resource Type | Location | Rationale |
|---------------|----------|-----------|
| App ServiceAccounts | `apps/<app>/` | Tied to app lifecycle |
| App-specific Roles | `apps/<app>/` | Only makes sense for that app |
| App NetworkPolicies | `apps/<app>/` | App understands its traffic patterns |
| App CiliumNetworkPolicies | `apps/<app>/` | Same as NetworkPolicies |
| Infra component RBAC | `infrastructure/<component>/` | Component-specific access |

### NetworkPolicy Placement Rule

Both `NetworkPolicy` and `CiliumNetworkPolicy` follow the same placement rule:

```
Security-layer namespaces (auth, security, external-secrets)
    → security/network-policies/

Application namespaces (homepage, jenkins, coder, etc.)
    → apps/<app>/
```

This applies regardless of whether you're using standard Kubernetes NetworkPolicies or Cilium-specific policies.

**Centralized here** are resources that:
- Span multiple applications (team RBAC)
- Are security infrastructure (auth, secrets)
- Require central governance (namespace policies)

## ArgoCD Applications

Each subdirectory has a corresponding ArgoCD Application:

| Directory | ArgoCD App | Sync Wave |
|-----------|------------|-----------|
| `security/namespaces` | `security-namespaces` | -89 (before workloads) |
| `security/network-policies` | `security-network-policies` | -88 |
| `security/rbac` | `security-rbac` | -87 |
| `security/resource-quotas` | `security-resource-quotas` | -86 |

## Related Documentation

- [Namespace Management](namespaces/base/README.md)
- [Network Policies](network-policies/base/README.md)
- [RBAC](rbac/base/README.md)
- [Admission Policies](../policies/README.md) - Separate directory for validation
