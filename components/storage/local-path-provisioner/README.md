# local-path-provisioner component

Purpose: install a lightweight default storage provisioner for local/non-longhorn clusters.

What it installs:
- `Namespace` `local-path-storage`
- RBAC and service account for the provisioner
- `local-path-config` `ConfigMap`
- `Deployment` for `rancher/local-path-provisioner`
- default `StorageClass` named `local-path`

Usage:

```yaml
components:
  - ../../../../components/storage/local-path-provisioner
```

This component is environment-agnostic and contains no secret values.
