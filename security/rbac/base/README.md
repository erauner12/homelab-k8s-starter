# Security RBAC

This directory manages **platform and team RBAC** - access control that spans multiple applications or represents organizational structure.

## Structure

```
security/rbac/
├── base/
│   ├── gateway-api/
│   │   ├── clusterrole-app-team-httproute-editor.yaml
│   │   ├── clusterrole-netops-gateway-admin.yaml
│   │   └── rolebinding-homepage-app-team-routes.yaml
│   └── kustomization.yaml
└── overlays/
    └── home/
```

## What Belongs Here

**Centralized RBAC** for:

| Type | Example | Rationale |
|------|---------|-----------|
| Team ClusterRoles | `app-team-httproute-editor` | Reusable across namespaces |
| Platform ClusterRoles | `netops-gateway-admin` | Platform-wide access |
| Cross-namespace RoleBindings | Team access to shared resources | Organizational structure |

## What Stays With Applications

**Application-specific RBAC** stays with the app:

| Resource | Location | Rationale |
|----------|----------|-----------|
| App ServiceAccounts | `apps/<app>/` | Tied to app lifecycle |
| App-specific Roles | `apps/<app>/` | Only makes sense for that app |
| Workload RBAC | `apps/<app>/` | Controller/operator specific |

Examples that stay with apps:
- `apps/jenkins/base/agent-rolebinding.yaml` - Jenkins agent access
- `apps/coder/overlays/production/coder-rolebinding.yaml` - Coder workspace access
- `apps/kasm/overlays/production/clusterrole-kubevirt.yaml` - KubeVirt VM access

## Design Principles

1. **Least privilege** - Grant minimum required access
2. **Team-based** - RBAC follows organizational structure, not individual users
3. **Namespace scoping** - Use RoleBindings to scope ClusterRoles per namespace
4. **Separation of duties** - Different roles for different responsibilities

## ClusterRole Hierarchy

```
netops-gateway-admin (platform team)
    └── Full Gateway API + EnvoyProxy access

app-team-httproute-editor (application teams)
    └── HTTPRoute/GRPCRoute management only
    └── No Gateway or GatewayClass access
```

## Adding New RBAC

1. **For platform/team access**: Add to `security/rbac/base/`
2. **For app-specific access**: Add to `apps/<app>/`
3. **For infra component access**: Add to `infrastructure/<component>/`

## Related

- `security/namespaces/` - Namespace definitions that RBAC applies to
- `security/network-policies/` - Network-level access control
- Application RBAC in `apps/*/` directories
