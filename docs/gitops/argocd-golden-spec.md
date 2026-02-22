# ArgoCD Application Golden Spec

This document defines the standard pattern for all ArgoCD Applications in the homelab.

## 🎯 Key Principles

1. **Multi-source pattern** for Helm charts with external values
2. **Ref sources MUST NOT have paths** - This is critical!
3. **Standard retry and sync policies** for resilience
4. **Consistent ignoreDifferences** for known immutable fields
5. **Namespace label management** to prevent Flux conflicts

## 📋 The Golden Spec

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: <app-name>
  namespace: argocd
  labels:
    app.kubernetes.io/managed-by: argocd
    homelab.dev/managed-by: argocd
    homelab.dev/layer: <apps|infra|security|observability>
    app.kubernetes.io/name: <app-name>
    app.kubernetes.io/part-of: <project>
  annotations:
    argocd.argoproj.io/sync-wave: "20"  # Apps use 20, infra uses lower
    homelab.dev/description: "<description>"
spec:
  project: <project>  # apps-runtime, devops, mcp, security, observability

  sources:
    # 1. Helm chart source (primary renderer)
    - repoURL: <helm-repo-url>
      chart: <chart-name>
      targetRevision: "<version>"
      helm:
        valueFiles:
          - $values/apps/<app-name>/base/values.yaml

    # 2. Git source ONLY for value files
    # ⚠️ CRITICAL: No path field here! This caused "Object 'Kind' is missing" errors
    - repoURL: git@github.com:erauner/homelab-k8s.git
      targetRevision: master
      ref: values  # This is ONLY a reference name, not a path!

    # 3. Optional: Kustomize overlay for additional resources
    - repoURL: git@github.com:erauner/homelab-k8s.git
      targetRevision: master
      path: apps/<app-name>/overlays/production

  destination:
    server: https://kubernetes.default.svc
    namespace: <target-namespace>

  syncPolicy:
    automated:
      prune: true
      selfHeal: true

    retry:
      limit: 5
      backoff:
        duration: 5s
        factor: 2
        maxDuration: 3m

    syncOptions:
      - CreateNamespace=true
      - PrunePropagationPolicy=foreground
      - PruneLast=true
      - RespectIgnoreDifferences=true

    managedNamespaceMetadata:
      labels:
        homelab.dev/managed-by: argocd
        homelab.dev/layer: <layer>
        # Prevent Flux label ping-pong
        kustomize.toolkit.fluxcd.io/name: ""
        kustomize.toolkit.fluxcd.io/namespace: ""
      annotations:
        homelab.dev/description: "Application namespace managed by ArgoCD"
        # Pod Security Standards
        pod-security.kubernetes.io/enforce: restricted
        pod-security.kubernetes.io/audit: restricted
        pod-security.kubernetes.io/warn: restricted

  ignoreDifferences:
    # PVC fields that cannot be changed
    - group: ""
      kind: PersistentVolumeClaim
      jsonPointers:
        - /spec/volumeName
        - /spec/storageClassName
    # HTTPRoute status is managed by the gateway
    - group: gateway.networking.k8s.io
      kind: HTTPRoute
      jsonPointers:
        - /status

  revisionHistoryLimit: 3
```

## ⚠️ Common Pitfalls

### 1. Path on ref sources
**WRONG:**
```yaml
- repoURL: git@github.com:erauner/homelab-k8s.git
  targetRevision: master
  ref: values
  path: apps/myapp/base  # ❌ This causes ArgoCD to render ALL files as manifests!
```

**CORRECT:**
```yaml
- repoURL: git@github.com:erauner/homelab-k8s.git
  targetRevision: master
  ref: values  # ✅ No path - it's just a reference name
```

### 2. Source ordering
Sources should be in this order:
1. Helm chart (primary renderer)
2. Values ref (no path!)
3. Additional overlays (with path)

### 3. Missing retry policy
Without retry, transient failures cause sync to fail permanently until manual intervention.

## 🔧 Automation & Enforcement

### Kyverno Policies
Located in `infrastructure/base/kyverno/policies/argocd/`:
- `disallow-values-source-path.yaml` - Prevents path on ref sources
- `default-application-settings.yaml` - Adds standard settings
- `require-sync-wave.yaml` - Ensures sync-wave annotation

### Lint Script
Run before committing:
```bash
./hack/lint-argocd-apps.sh
```

### Backstage Template
Create new apps with:
```
.backstage/templates/argocd-application/
```

## 📊 Sync Waves

- `-20`: AppProjects
- `-10`: ApplicationSets
- `0-10`: Infrastructure (storage, networking, operators)
- `20`: Applications (default)
- `30+`: Post-deployment jobs

## 🔄 Migration

To migrate existing apps to golden spec:
```bash
# Standardize all applications
./hack/standardize-argocd-apps.sh

# Fix ref sources with paths
./hack/fix-ref-sources.sh

# Validate
./hack/lint-argocd-apps.sh
```

## 🤝 Flux Coexistence

- ArgoCD manages: Application CRs, namespaces they create
- Flux manages: Infrastructure, ArgoCD itself
- Empty Flux labels prevent ping-pong: `kustomize.toolkit.fluxcd.io/name: ""`

## 📚 References

- [ArgoCD Multi-Source Applications](https://argo-cd.readthedocs.io/en/stable/user-guide/multiple_sources/)
- [Kustomize Build Options](https://argo-cd.readthedocs.io/en/stable/user-guide/kustomize/)
- [Sync Waves and Hooks](https://argo-cd.readthedocs.io/en/stable/user-guide/sync-waves/)
