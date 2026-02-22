# Resource Quotas

This directory manages ResourceQuotas and LimitRanges for namespace resource governance.

## Structure

```
security/resource-quotas/
├── base/
│   ├── namespaces/       # Per-namespace quotas (future)
│   ├── defaults/         # Default LimitRanges (future)
│   └── kustomization.yaml
└── overlays/
    └── home/
```

## Current Status

**Initially empty** - No quotas are enforced to avoid disrupting existing workloads.

## Adding Quotas Safely

1. **Monitor first** - Use Prometheus/Grafana to observe actual resource usage
2. **Start high** - Set quotas at 2-3x observed usage
3. **Warn before enforce** - Use admission webhooks to warn before hard limits
4. **Tighten gradually** - Reduce limits after validating workloads handle them

## Example ResourceQuota

```yaml
apiVersion: v1
kind: ResourceQuota
metadata:
  name: auth-namespace-quota
  namespace: auth
spec:
  hard:
    requests.cpu: "4"
    requests.memory: 8Gi
    limits.cpu: "8"
    limits.memory: 16Gi
    pods: "20"
    services: "10"
```

## Example LimitRange

```yaml
apiVersion: v1
kind: LimitRange
metadata:
  name: default-limits
  namespace: auth
spec:
  limits:
  - default:
      cpu: 500m
      memory: 512Mi
    defaultRequest:
      cpu: 100m
      memory: 128Mi
    type: Container
```

## Design Principles

1. **Non-disruptive** - Don't break running workloads
2. **Observable** - Monitor before enforcing
3. **Gradual** - Tighten limits over time
4. **Per-namespace** - Different limits for different use cases

## Related

- `security/namespaces/` - Namespace definitions that quotas apply to
- Prometheus/Grafana for resource usage monitoring
