# Talos Without Omni

This folder captures the Omni-derived Talos baseline as standalone patch files.

## What this gives you

- Reusable `talosctl gen config` patches for cluster, control plane, and workers.
- A starting point for reproducing your Omni pattern without Omni API dependencies.

## Files

- `talos/patches/cluster-base.yaml`
- `talos/patches/controlplane-base.yaml`
- `talos/patches/worker-base.yaml`
- `talos/patches/machine-kubelet.yaml`
- `talos/patches/machine-hostdns.yaml`
- `talos/patches/longhorn-install.yaml`
- `talos/generate-config.sh`

## Generate standalone machine configs

```bash
# Optional overrides
export CLUSTER_NAME=starter-home
export ENDPOINT=https://192.168.1.193:6443
export KUBERNETES_VERSION=1.31.5
export INSTALL_DISK=/dev/sda
export ENABLE_LONGHORN=true

./talos/generate-config.sh
```

Output goes to `talos/generated/`:

- `controlplane.yaml`
- `worker.yaml`
- `talosconfig`

## Notes

- Replace subnet and endpoint defaults before production use.
- This is intentionally minimal; add machine-specific hostname/IP patches per node.
- Omni-only machine UUID mapping is not carried over.
- Nexus/Spegel mirror config is intentionally excluded for now.
