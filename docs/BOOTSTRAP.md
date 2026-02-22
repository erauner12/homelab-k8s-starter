# Cluster Bootstrap Guide

This guide describes the "nuke & pave" bootstrap process for the homelab-k8s cluster using the enhanced `homelabctl` tool with staged GitOps architecture.

## Overview

The bootstrap process is designed to be:
- **Idempotent**: Safe to run repeatedly
- **Ordered**: CRDs → secrets → namespaces → infrastructure → operators → ArgoCD
- **Self-describing**: All configuration lives in Git
- **Secret-ready**: SOPS/age keys and provider secrets are available before components need them
- **Smoke-tested**: Automated validation ensures the stack is healthy

## Quick Start

```bash
# 1. Ensure you have a running Kubernetes cluster
kubectl cluster-info

# 2. Ensure SOPS age key is available (for secret decryption)
ls ~/.config/sops/age/keys.txt

# 3. Bootstrap the entire cluster
./bin/homelabctl bootstrap run
# OR
make bootstrap

# 4. Verify everything is working
./bin/homelabctl bootstrap smoke
# OR
make smoke

# 5. Check status
make status
```

## Enhanced homelabctl Bootstrap

The `homelabctl bootstrap` command provides a comprehensive, staged approach to cluster bootstrapping:

### Available Commands

```bash
# Complete bootstrap pipeline
homelabctl bootstrap run

# Show what would be executed (dry-run)
homelabctl bootstrap plan

# Run smoke tests independently
homelabctl bootstrap smoke

# Bootstrap specific stage (future)
homelabctl bootstrap stage --stage crds

# Resume interrupted bootstrap (future)
homelabctl bootstrap resume

# Clean up all bootstrap resources (future)
homelabctl bootstrap cleanup
```

### Bootstrap Pipeline

The bootstrap pipeline consists of these steps:

1. **PreflightChecks** - Validate prerequisites and environment
2. **DetectCluster** - Validate cluster readiness and connectivity
3. **InstallFluxRuntime** - Install Flux controllers and CRDs
4. **CreateSecrets** - Create SOPS age keys and bootstrap secrets
5. **StagedGitOps** - Apply GitOps configuration in staged approach
6. **SmokeTests** - Comprehensive health validation

## Prerequisites

### Required Tools
- `kubectl` - Kubernetes CLI
- `flux` - Flux CLI (v2.0+)
- `make` - Build automation (for Makefile commands)
- Go toolchain (for building homelabctl)

### Required Secrets

The bootstrap process expects these secrets to exist:

1. **SOPS Age Key** (`~/.config/sops/age/keys.txt`)
   - Used for decrypting secrets in the repository
   - Must be the same key used to encrypt `bootstrap/secrets/*.sops.yaml`

2. **Cloudflare API Token** (`bootstrap/secrets/cloudflare-token.sops.yaml`)
   - Used by External-DNS for managing DNS records
   - Requires `Zone:Edit` permissions for `erauner.dev`

3. **Container Registry Credentials** (`bootstrap/secrets/ghcr-creds.sops.yaml`)
   - Used for pulling private container images from GHCR
   - GitHub Personal Access Token with `packages:read` scope

---

## 1.5. Validate Cluster Readiness

Before installing Flux, ensure your cluster is healthy and ready:

```bash
# Verify all nodes are ready
kubectl get nodes
# All nodes should show STATUS: Ready

# Check system pods are running
kubectl get pods --all-namespaces
# Core components (kube-system, cilium) should be Running

# Verify CNI networking
kubectl -n cilium get pods
# Cilium pods should be Running on all nodes

# Test cluster connectivity
kubectl cluster-info
# Should show healthy API server and DNS
```

**Expected healthy cluster output:**
- 4 nodes: 1 control-plane + 3 workers, all `Ready`
- Cilium CNI pods running on all nodes
- CoreDNS pods running and healthy
- No `CrashLoopBackOff` or `Error` pods in system namespaces

---

## 2. Install Flux runtime in-cluster

```bash
# creates CRDs, controllers, NetworkPolicies … in kube-system/flux-system
flux install
```

Check they’re healthy:

```bash
flux check --pre          # sanity
flux check                # after install
kubectl -n flux-system get pods
```

---

## 2½. Create SOPS & Git deploy-key secrets *before* first Flux sync

> **Both secrets must exist before Flux can successfully reconcile `home-infra` / `cloud-infra`.**

**a. SOPS AGE key**

```bash
kubectl -n flux-system apply --validate=false -f clusters/<env>/bootstrap/sops-age-secret.yaml
```
- Use `--validate=false` to allow the `sops:` block to pass validation.

**b. Git deploy-key secret (SSH private key and known_hosts)**

```bash
ssh-keyscan github.com > /tmp/known_hosts
kubectl -n flux-system create secret generic flux-system \
  --from-file=identity=$HOME/.ssh/id_ed25519 \
  --from-file=identity.pub=$HOME/.ssh/id_ed25519.pub \
  --from-file=known_hosts=/tmp/known_hosts
```
- Keys **must** be named `identity`, `identity.pub`, and `known_hosts`.

**c. GitHub Container Registry image pull secret (for custom images)**

For custom container images hosted on GitHub Container Registry (like `ghcr.io/erauner12/synology-csi-talos`), create a SOPS-encrypted image pull secret:

```bash
# The secret is already defined in infrastructure/home/synology-csi/ghcr-secret.sops.yaml
# It will be automatically applied when home-infra kustomization is reconciled
# Contains GitHub Personal Access Token with read:packages permission
```

*Proceed to bootstrap only after all secrets are in place.*

---

## 3. Bootstrap Flux against your repo (SSH method)

> The winning command we used:

```bash
export REPO_URL=ssh://git@github.com/erauner12/homelab-k8s
export BRANCH=master               # use your real default branch
export BOOTSTRAP_PATH=clusters/home/flux
flux bootstrap git \
  --url=$REPO_URL \
  --branch=$BRANCH \
  --path=$BOOTSTRAP_PATH \
  --private-key-file=$HOME/.ssh/id_ed25519   # key that *already* works from your laptop
```

What happens:

1. **Flux-CLI clones `main`** using *your* key, adds the `flux-system` manifests, commits & pushes.

2. It **generates a new deploy key pair for the cluster** and prints the public part:

   ```
   ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIDKWzJ1QtyFbUkIWfo+RKwhuSA… flux-system
   ```

3. **Add this public key to GitHub**
   *Repo ▸ Settings ▸ Deploy keys ▸ "Add key" ▸ check "Allow write"*.
   (You typed `y` after you pasted it and the bootstrap continued.)

4. Flux applies the `GitRepository` + `Kustomization` under `clusters/home/flux`.

5. CLI waits until both are **Ready=True** and all controllers are healthy.

---

## 4. Verify the sync

```bash
# Git source itself
flux get sources git

# All kustomizations rolling out (watch for infra → apps cascade)
flux get kustomizations --watch
```

- If you see `secrets "sops-age" not found`, the secret may be missing or in the wrong namespace (`flux-system`). Double-check it exists in `flux-system`.

For deeper dives:

```bash
flux logs --level=error                  # tail controller errors
kubectl -n flux-system logs deploy/kustomize-controller
```

When everything is green you should see:

```
home-infra   Ready True  Applied revision: main@sha1:…
home-apps    Ready True  Applied revision: main@sha1:…
```

---

## 5. Typical day-two commands

| Action                          | Command                                                |
| ------------------------------- | ------------------------------------------------------ |
| Force re-sync a Git source      | `flux reconcile source git homelab-k8s`                |
| Force reconcile a kustomization | `flux reconcile kustomization home-apps --with-source` |
| See HelmReleases                | `flux get helmreleases -A`                             |
| Diff against live cluster       | `flux diff kustomization home-apps`                    |

### Load Balancer Test Applications

The homelab now deploys two `lb-test` variants for comprehensive storage testing:

- **lb-test-nfs** (namespace: `demo-nfs`) - Tests NFS storage with RWX capabilities
- **lb-test-iscsi** (namespace: `demo-iscsi`) - Tests iSCSI storage with RWO block volumes

Both variants run in parallel to demonstrate the different storage backends and allow for performance comparisons. Each has its own hostname:
- `lb-test-nfs.erauner.dev`
- `lb-test-iscsi.erauner.dev`

To check both variants:
```bash
kubectl get pods -n demo-nfs -l app=lb-test
kubectl get pods -n demo-iscsi -l app=lb-test
```

---

## 6. Troubleshooting tips

* **Branch typos** → Flux prompts for HTTPS password (Git can’t find `master`).
  Use the real branch (`master`).

* **SSH handshake failed** → either wrong key file or deploy key not added yet.

* **`Progressing` forever** → inspect the object:

  ```bash
  kubectl -n flux-system describe kustomization home-apps
  ```

* **Helm chart issues** → `kubectl -n <ns> get helmrelease <name> -o yaml` and look at
  `.status.conditions[].message`.

* **Cleanup Pitfalls** → Never manually patch cluster-wide roles like `cluster-admin` or `edit`. If you encounter a permission error, the correct fix is to regenerate the component manifests with `flux install --export` and commit the result. Manual patches are ephemeral and will be reverted by GitOps.

---

### Nuke everything (controllers and CRDs) and start fresh

If you need to completely reset the Flux installation due to stuck resources (e.g., a CRD in a `Terminating` state) or other unrecoverable errors, the following steps will perform a clean wipe of all Flux components before re-bootstrapping. This process is destructive and will remove all Flux-managed resources and history.

The entire process is automated by the `scripts/nuke_flux.sh` script.

If you wish to perform the steps manually, or if the script fails, here is a detailed runbook for re-bootstrapping after a full wipe.

#### Why the bootstrap can fail

| Symptom                                                                                                            | Root-cause                                                                                                                                                                                                               |
| ------------------------------------------------------------------------------------------------------------------ | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| `Secret in version "v1" cannot be handled … unknown field "sops"`                                                  | You tried to `kubectl apply` an **encrypted** SOPS document.  The apiserver’s strict decoder rejects the extra top-level `sops:` key unless you bypass validation.                                                       |
| `invalid 'ssh' auth option: 'identity' is required`<br/>`Secret "flux-system" is invalid: data[ssh-privatekey]: Required value`<br/>`exactly one NAME is required, got 24` | Flux expects the SSH Secret to have keys named `identity` (private key) and `identity.pub` (public key). If you use `--type=kubernetes.io/ssh-auth` and keys like `ssh-privatekey`, Flux will not find them and will fail with this error. |
| `CiliumBGPPeeringPolicy ... is invalid: ... neighbors: Required value`                                             | Your patch or policy deleted the required `neighbors` block; ensure you have a valid `bgp-policy.yaml` with the full `neighbors` configuration and commit/apply it.                                                      |
| `accumulating resources ... no matches for Id ... gitea-staging`                                                   | Your `patchesJson6902` target references the post-`nameSuffix` resource; you must target the *base* name before `nameSuffix` is applied in overlay kustomizations.                                                      |

#### Manual Re-Bootstrap Steps

These steps assume you have already run the "nuke" part of the `nuke_flux.sh` script, or manually deleted the `flux-system` namespace and Flux CRDs.

**1. Create the AGE key Secret (skip validation)**
```bash
kubectl -n flux-system apply \
  --validate=false \
  -f clusters/home/bootstrap/sops-age-secret.yaml
```
*Why `--validate=false`?* – it tells kubectl **"don’t run structural validation"**, so the unknown `sops:` block is allowed. Flux (or your local SOPS tooling) can still decrypt it later.

**2. Create the Git deploy-key Secret with the correct key names**
```bash
# Save GitHub host key once
ssh-keyscan github.com > /tmp/known_hosts

# Remove any previous secret with wrong keys
kubectl -n flux-system delete secret flux-system || true

# Create the secret with the key names Flux expects
kubectl -n flux-system create secret generic flux-system \
  --from-file=identity=$HOME/.ssh/id_ed25519 \
  --from-file=identity.pub=$HOME/.ssh/id_ed25519.pub \
  --from-file=known_hosts=/tmp/known_hosts
```
*Notes*:
* The secret type can remain the default `Opaque`; Flux ignores the `type:` field.
* **Key names must be exactly `identity` (private key), `identity.pub` (public key), and `known_hosts`.**
* If you use `--type=kubernetes.io/ssh-auth` and keys like `ssh-privatekey`, Flux will not find them and will fail with `invalid 'ssh' auth option: 'identity' is required`.

| Key            | Required | Purpose                       |
| -------------- | -------- | ----------------------------- |
| `identity`     | ✔        | **private** SSH key           |
| `identity.pub` | ✱        | public key (helps for debug)  |
| `known_hosts`  | ✱        | pin GitHub’s host fingerprint |

**3. Re-apply Flux runtime & sync manifests**
```bash
# 3-a  CRDs + controllers
kubectl apply -f clusters/home/flux/flux-system/gotk-components.yaml \
  --server-side --force-conflicts --field-manager=flux

# 3-b  Bootstrap-sync objects
kubectl apply -f clusters/home/flux/flux-system/gotk-sync.yaml
```

**4. Kick reconciliation once**
```bash
# Git source should go Ready within ~15 s
flux reconcile source git flux-system -n flux-system

# Then the kustomization (which in turn creates homelab-k8s etc.)
flux reconcile kustomization flux-system -n flux-system --with-source
```

---

### A Note on Regenerating `gotk-components.yaml`

After a recovery where you used `--force-conflicts` to repair field managers, it is recommended to regenerate `gotk-components.yaml` to ensure your Git repository matches the live cluster state.

Run this command locally and commit the resulting file:
```bash
flux install --export --components-extra=image-reflector-controller,image-automation-controller \
  > clusters/home/flux/flux-system/gotk-components.yaml
```

---

### Quick checklist for future bootstrap runs

1.  **AGE key secret**

    ```bash
    kubectl -n flux-system apply --validate=false -f clusters/home/bootstrap/sops-age-secret.yaml
    ```
2.  **SSH deploy-key secret (Opaque, keys named `identity*`)**

    ```bash
    ssh-keyscan github.com > /tmp/known_hosts
    kubectl -n flux-system create secret generic flux-system \
      --from-file=identity=$HOME/.ssh/id_ed25519 \
      --from-file=identity.pub=$HOME/.ssh/id_ed25519.pub \
      --from-file=known_hosts=/tmp/known_hosts
    ```
3.  Apply `gotk-components.yaml` and `gotk-sync.yaml`.
4.  **Manually reconcile Flux sources/kustomizations to ensure they are evaluated as soon as secrets are ready**:

    ```bash
    flux reconcile source git flux-system -n flux-system
    flux reconcile kustomization home-infra -n flux-system --with-source
    flux reconcile kustomization home-apps -n flux-system --with-source
    ```

After those four steps your cluster should be fully GitOps-driven again.

---

### Appendix A – PAT method (alt)

If you prefer HTTPS and a GitHub Personal Access Token:

```bash
export GITHUB_TOKEN=ghp_xxx          # scopes: repo
flux bootstrap git \
  --url=https://github.com/erauner12/homelab-k8s \
  --branch=master \
  --path=clusters/home/flux \
  --token-auth
```

Flux will store an **SSH deploy key** in-cluster for ongoing use; the PAT is only used once during bootstrap.

---

## Appendix B – HelmRepository: Dual HTTP and OCI Best Practices

> **About dual HelmRepository sources**
> Some Helm chart vendors (notably `bjw-s`) now publish charts as both classic HTTP "index.yaml" and OCI container registry artifacts. You can (and often should) maintain both repository objects side-by-side, and point each HelmRelease to the one that actually contains its desired chart version.

### Maintaining Both HTTP and OCI Repositories

**Example configuration:**

```yaml
# Classic HTTP HelmRepository
apiVersion: source.toolkit.fluxcd.io/v1
kind: HelmRepository
metadata:
  name: bjw-s-http
  namespace: flux-system
spec:
  url: https://bjw-s-labs.github.io/helm-charts/
  interval: 30m

---
# OCI HelmRepository
apiVersion: source.toolkit.fluxcd.io/v1
kind: HelmRepository
metadata:
  name: bjw-s-oci
  namespace: flux-system
spec:
  type: oci
  url: oci://ghcr.io/bjw-s/helm-charts
  interval: 30m
```

### How to wire up your HelmRelease

- For charts still published on the HTTP index:
  ```yaml
  spec:
    chart:
      spec:
        chart: some-other-chart
        version: 1.2.3
        sourceRef:
          kind: HelmRepository
          name: bjw-s-http
          namespace: flux-system
  ```
- For OCI-only charts (e.g., `app-template` >= v3.7):
  ```yaml
  spec:
    chart:
      spec:
        chart: app-template
        version: 3.7.3
        sourceRef:
          kind: HelmRepository
          name: bjw-s-oci
          namespace: flux-system
  ```

> **Note:**
> You do **not** need to use an `oci://` prefix in the `chart:` field.
> Just point the `sourceRef` at the correct repo type; Flux resolves which protocol to use based on the repository CRD.

### Reconciliation and troubleshooting

If you add a new HelmRepository, or switch references:
- Reconcile the repository so Flux is aware of it:
  ```sh
  flux reconcile source helm bjw-s-oci -n flux-system --with-source
  ```
- Then reconcile any HelmReleases or HelmCharts that reference it:
  ```sh
  flux reconcile helmrelease <name> -n <namespace> --with-source
  # Or, for HelmChart:
  flux reconcile helmchart <name> -n flux-system
  ```
If the HelmRelease fails on "source not found" or similar, check the repo's Ready state, and that the names and namespaces of `sourceRef` exactly match the HelmRepository.

---

### Safe to keep both side-by-side

This pattern is fully supported and is recommended when some charts are available only over HTTP, and others only over OCI.
Each HelmRelease can individually reference the required repo; there's no need to remove or rename the old object unless you are sure you no longer need it.

You can register any number of HelmRepository objects — just ensure `spec.chart.spec.sourceRef.{kind,name,namespace}` matches the chart source you want.
```
