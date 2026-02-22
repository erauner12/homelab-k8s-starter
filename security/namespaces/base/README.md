# Security Namespaces

This directory manages namespaces for security infrastructure components.

## Structure

```
security/namespaces/
├── base/
│   ├── _system/          # Security-layer system namespaces
│   │   ├── auth.yaml           # Authentication services (Dex, OAuth2)
│   │   ├── security.yaml       # Security tools (1Password Connect)
│   │   └── ...                 # Additional platform security namespaces
│   └── kustomization.yaml
└── overlays/
    └── home/             # Home cluster overlay
```

## Purpose

These namespaces are separated from general infrastructure namespaces because:

1. **Security boundary** - Security-related workloads have stricter requirements
2. **Repo splitting readiness** - Can be extracted to a `deployment-security` repo
3. **Access control** - Security team can own this directory/repo
4. **Audit trail** - Security-related changes in one place

## Namespaces

| Namespace | Purpose | PSS Level |
|-----------|---------|-----------|
| `auth` | Authentication services (Dex, OAuth2 Proxy) | restricted |
| `security` | Security tools (1Password Connect, secret stores) | platform default |

## Related

- `security/rbac/` - RBAC for security infrastructure
- `security/network-policies/` - Network segmentation for security namespaces
- `infrastructure/namespaces/` - Non-security infrastructure namespaces
