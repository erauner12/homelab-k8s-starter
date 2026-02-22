# Argo CD app layout: bundled vs split (and multi-tenant options)

## TL;DR

* **Homelab default (bundled):** 1 ArgoCD Application per product (app + DB + extras).
* **Company default (split):** 2 Applications: `<app>-db` (platform-owned) and `<app>` (app-owned), ordered by sync waves.
* **Multi-tenant:** use an **ApplicationSet** (matrix or list generators) to stamp out N copies of either pattern.

---

## 1) Golden invariants (apply to all child Applications)

* `sources[0]` is the **renderer** (Helm chart *or* Git path).
* `$values` **ref-only** source has **no `path`**.
* Every child has `argocd.argoproj.io/sync-wave: "20"` (Projects `-20`, AppSets `-10`).
* `syncPolicy.automated: { prune: true, selfHeal: true }`
* `syncOptions`: `CreateNamespace=true`, `PrunePropagationPolicy=foreground`, `PruneLast=true`, `RespectIgnoreDifferences=true`
* Namespace labels in `managedNamespaceMetadata.labels` include the empty Flux keys to avoid relabel ping-pong:

  ```yaml
  kustomize.toolkit.fluxcd.io/name: ""
  kustomize.toolkit.fluxcd.io/namespace: ""
  ```

---

## 2) Pattern A — **Bundled (homelab default)**

**When to choose:** per-app CNPG, simple lifecycle, one PR spins up everything.

### Shape

```
apps/
  <app>/
    base/values.yaml
    db/overlays/production/          # CNPG Cluster, backups, etc. (Kustomize)
    overlays/production/             # HTTPRoute, certs, extras (Kustomize)
argocd-apps/applications/<app>.yaml  # 3–4 sources
```

### Application (example: `vikunja` - 4 sources)

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: vikunja
  namespace: argocd
  annotations:
    argocd.argoproj.io/sync-wave: "20"
spec:
  project: apps-runtime
  sources:
    # 1) Helm renderer
    - repoURL: https://bjw-s-labs.github.io/helm-charts
      chart: app-template
      targetRevision: "4.1.2"
      helm:
        valueFiles:
          - $values/apps/vikunja/base/values.yaml
    # 2) Values-only (no path!)
    - repoURL: git@github.com:erauner/homelab-k8s.git
      targetRevision: master
      ref: values
    # 3) DB overlay (Kustomize) - bundled pattern
    - repoURL: git@github.com:erauner/homelab-k8s.git
      targetRevision: master
      path: apps/vikunja/db/overlays/production
    # 4) App extras overlay (HTTPRoute, certificates, etc.)
    - repoURL: git@github.com:erauner/homelab-k8s.git
      targetRevision: master
      path: apps/vikunja/overlays/production
  destination:
    server: https://kubernetes.default.svc
    namespace: vikunja
  syncPolicy: { automated: { prune: true, selfHeal: true }, ... }
```

**Note**: This 4-source pattern is acceptable for bundled apps where the components are tightly coupled. For optimization, consider aggregating overlays into a single stack overlay to reduce to 3 sources.

### Ordering the DB before the app

Add a Kustomize patch in `apps/vikunja/db/overlays/production` that stamps a sync wave on CNPG objects:

```yaml
# patch-wave.yaml (included via kustomization.yaml/patches)
apiVersion: postgresql.cnpg.io/v1
kind: Cluster
metadata:
  name: vikunja-db
  annotations:
    argocd.argoproj.io/sync-wave: "-10"
```

(Repeat for `Backup`, `ScheduledBackup`, etc., if present.)

### Make the app tolerant of DB bring-up

* Point the app at the **CNPG RW service** (`<cluster>-rw`).
* Add a small **initContainer** or rely on app retries:

```yaml
# apps/vikunja/base/values.yaml (extract)
controllers:
  main:
    initContainers:
      wait-db:
        image: alpine
        command: ["/bin/sh","-c","until nc -z vikunja-db-rw 5432; do sleep 2; done"]
```

---

## 3) Pattern B — **Split (company default)**

**When to choose:** separate ownership, backups/maintenance windows, major DB upgrades independent of app.

### Shape

```
apps/<app>/base/values.yaml
apps/<app>/overlays/production/
apps/<app>/db/overlays/production/

argocd-apps/applications/<app>.yaml        # app only (3 sources)
argocd-apps/applications/<app>-db.yaml     # db only (1 source)
```

### `<app>-db` Application

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: vikunja-db
  namespace: argocd
  annotations:
    argocd.argoproj.io/sync-wave: "-20"
spec:
  project: apps-runtime
  source:
    repoURL: git@github.com:erauner/homelab-k8s.git
    targetRevision: master
    path: apps/vikunja/db/overlays/production
  destination:
    server: https://kubernetes.default.svc
    namespace: vikunja
  syncPolicy: { automated: { prune: true, selfHeal: true } }
```

### `<app>` Application (trim to 3 sources)

* Helm renderer
* `$values` (ref-only)
* App extras (HTTPRoute, etc.)

The parent app-of-apps ensures **DB (-20) → App (20)** ordering.

---

## 4) Multi-tenant options (pick later)

### A) App-of-apps (no ApplicationSet)

* One YAML per tenant, e.g. `argocd-apps/applications/vikunja-<tenant>.yaml`.
* Simple, explicit diffs; good for < ~10 tenants.

### B) ApplicationSet (recommended for N tenants)

* **list generator** reading a tenants file, or **matrix** (env × tier).
* Each item sets `name: vikunja-{{tenant}}`, `namespace: vikunja-{{tenant}}`, and points Helm to `$values/apps/vikunja/tenants/{{tenant}}/values.yaml`.
* For **split DB** per tenant: create a second ApplicationSet `vikunja-db-<tenant>` with wave `-20`.

> Keep `$values` **ref-only** in the template. Do not add `path` to the `$values` source.

---

## 5) Migration guides

### Bundled → Split (zero confusion)

1. **Create `<app>-db` Application** (wave `-20`) pointing to existing DB overlay.
2. **Remove DB source** from `<app>` Application.
3. **PR merges** → parent syncs → DB and App apply independently.
4. Verify the app still points to the same CNPG service (`-rw`) and secrets.

### Split → Bundled

1. **Add DB overlay source** to `<app>` Application and put `sync-wave: "-10"` on CNPG CRs.
2. **Delete `<app>-db` Application** (Argo will prune old DB objects only if they're no longer emitted—ensure the bundled app emits identical names).
3. Parent re-syncs; DB now managed by app.

---

## 6) Repo wiring (what to change/add now)

* Add this doc as `docs/gitops/argocd-app-layout.md`.

* Ensure **Backstage template** outputs:

  * **Bundled** by default (toggle for "Split DB").
  * `sources` `[helm, $values, overlay, (db overlay if bundled=true)]`.
  * `sync-wave: "20"` on the child Application.
  * CNPG patch with `sync-wave: "-10"` when bundled.

* **Source count monitoring**: Run `./hack/check-argocd-source-count.sh` to identify Applications with >3 sources:

  ```bash
  ./hack/check-argocd-source-count.sh
  # ⚠️  vikunja: has 4 sources (recommended: ≤3)
  #    Consider using a stack overlay to aggregate overlays into a single source
  ```

* **Kyverno policies** enforce golden spec invariants:

  * Block if `.spec.sources[] | select(.ref=="values") | has("path") == true`.
  * Require `.metadata.annotations["argocd.argoproj.io/sync-wave"]`.

---

## 7) Runbooks your engineer can use

### Verify cascade after a change

```bash
# Parent sees the push
argocd app get app-of-apps --grpc-web | rg 'Sync Status|commit'

# Show only unsynced children
argocd app get app-of-apps -o json --grpc-web \
 | jq -r '.status.resources[]
          | select(.kind=="Application" and .status!="Synced")
          | .name'

# Kick a specific child if needed
argocd app sync vikunja --grpc-web
```

### Force a clean re-check

```bash
kubectl -n argocd annotate application app-of-apps argocd.argoproj.io/refresh=hard --overwrite
argocd app wait app-of-apps --grpc-web --timeout 120
```

---

## 8) Quick decision table

| Need                                                 | Choose                      |
| ---------------------------------------------------- | --------------------------- |
| One PR spins up everything for a toy or side project | **Bundled**                 |
| DB upgrades/backups scheduled separately             | **Split**                   |
| Different teams own DB vs app                        | **Split**                   |
| ≤ 10 tenants, infrequent churn                       | App-of-apps per-tenant YAML |
| Many tenants, frequent churn                         | **ApplicationSet**          |

---
