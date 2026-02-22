# Security Network Policies

This directory manages NetworkPolicies for security infrastructure namespaces.

## Structure

```
security/network-policies/
├── base/
│   ├── auth/
│   │   └── dex-egress-omni.yaml      # Dex OIDC provider policies
│   ├── external-secrets/
│   │   └── external-secrets-operator.yaml  # ESO policies
│   ├── security/
│   │   └── onepassword-connect.yaml  # 1Password Connect policies
│   └── kustomization.yaml
└── overlays/
    └── home/
```

## Purpose

These NetworkPolicies are separated from application-specific policies because:

1. **Security boundary** - Security infrastructure requires stricter network controls
2. **Repo splitting readiness** - Can be extracted to `deployment-security` repo
3. **Centralized security governance** - All security network rules in one place
4. **Audit compliance** - Easy to review security-related network access

## Policies

| Namespace | Policy | Purpose |
|-----------|--------|---------|
| `auth` | `dex-egress-omni` | Controls Dex access to external OIDC providers |
| `external-secrets` | `external-secrets-operator` | Controls ESO access to secret stores |
| `security` | `onepassword-connect` | Controls 1Password Connect API access |

## Design Principles

1. **Default deny** - Start restrictive, add explicit allows
2. **Least privilege** - Only allow necessary traffic
3. **Namespace isolation** - Security namespaces isolated from application traffic
4. **Egress control** - Limit outbound access to required services

## NetworkPolicy vs CiliumNetworkPolicy

Both standard Kubernetes NetworkPolicies and CiliumNetworkPolicies follow the same placement rules:

| Policy Type | Security Layer | Application |
|-------------|----------------|-------------|
| NetworkPolicy | `security/network-policies/` | `apps/<app>/` |
| CiliumNetworkPolicy | `security/network-policies/` | `apps/<app>/` |

Use CiliumNetworkPolicies when you need:
- L7 (HTTP/gRPC) filtering
- DNS-based egress rules
- More granular pod selectors
- Cilium-specific features (identity-based policies)

## Related

- `security/namespaces/` - Security namespace definitions
- `security/rbac/` - RBAC for security infrastructure
- Application-specific NetworkPolicies remain with their apps
