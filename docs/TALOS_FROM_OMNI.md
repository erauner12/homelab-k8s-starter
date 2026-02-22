# Talos Standalone Port (From Omni)

This document maps your current Omni pattern to standalone Talos config files.

## Source of truth reviewed

- `/Users/erauner/git/side/omni/cluster-template-home.yaml`
- `/Users/erauner/git/side/omni/patches/cluster.yaml`
- `/Users/erauner/git/side/omni/patches/controlplane.yaml`
- `/Users/erauner/git/side/omni/patches/worker.yaml`
- `/Users/erauner/git/side/omni/patches/machine-kubelet.yaml`
- `/Users/erauner/git/side/omni/patches/machine-hostdns.yaml`
- plus cilium/longhorn install patches for optional parity

## What was extracted into this repo

- `talos/patches/cluster-base.yaml`
- `talos/patches/controlplane-base.yaml`
- `talos/patches/worker-base.yaml`
- `talos/patches/machine-kubelet.yaml`
- `talos/patches/machine-hostdns.yaml`
- `talos/patches/longhorn-install.yaml`
- `talos/generate-config.sh`

These are Omni-free and can be used directly with `talosctl gen config`.

## Mapping: Omni to standalone Talos

1. Omni `kind: Cluster` + `patches/cluster.yaml`
- Standalone: `talos/patches/cluster-base.yaml`
- Carries over:
  - `cni: none`
  - `proxy.disabled: true`
  - PodSecurity admission baseline defaults + exemptions
  - extra manifests (kubelet cert approver, metrics-server, gateway-api)
  - local-path StorageClass inline manifest

2. Omni `kind: ControlPlane` + `patches/controlplane.yaml`
- Standalone: `talos/patches/controlplane-base.yaml`
- Carries over:
  - kubelet cert rotation arg
  - `net.ifnames=0` kernel arg

3. Omni `kind: Workers` + `patches/worker.yaml`
- Standalone: `talos/patches/worker-base.yaml`
- Carries over:
  - kubelet cert rotation arg
  - `net.ifnames=0`
  - `bgp=enable` node label

4. Omni machine patch set
- Standalone:
  - `talos/patches/machine-kubelet.yaml`
  - `talos/patches/machine-hostdns.yaml`

## Included operators at Talos layer

- Cilium install job is included in `talos/patches/cluster-base.yaml`.
- Longhorn install job is included in `talos/patches/longhorn-install.yaml`.

## What is intentionally not ported yet

- Omni machine UUID-specific node sections and static-IP bindings
- cert files (`cluster-certs-*`, `machine-certs-*`)
- nexus/spegel registry mirror specifics

## Local validation strategy

Use Talos local cluster scripts:

- `scripts/talos/local-up.sh`
- `scripts/talos/local-status.sh`
- `scripts/talos/local-down.sh`

Default local bootstrap path applies `clusters/kind/bootstrap` after ArgoCD install to validate GitOps mechanics without cloud-specific dependencies.
