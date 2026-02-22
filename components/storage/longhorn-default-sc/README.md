# longhorn-default-sc component

Purpose: mark the `longhorn` `StorageClass` as the cluster default.

Expectation:
- A `StorageClass` named `longhorn` already exists (from Longhorn install path).

Usage:

```yaml
components:
  - ../../../../components/storage/longhorn-default-sc
```
