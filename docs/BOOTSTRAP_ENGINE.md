# Bootstrap Engine Guide

This guide covers using the new **`homelabctl bootstrap`** command to automatically set up Flux GitOps infrastructure on Kubernetes clusters. This engine provides a declarative, idempotent approach to bootstrapping that's safer and more reliable than manual setup.

## 🎯 **What This Solves**

The bootstrap engine eliminates the manual, error-prone process of:
- Installing Flux runtime components
- Creating required secrets (SOPS AGE keys, Git deploy keys)
- Configuring Git repository access
- Bootstrapping Flux with proper authentication
- Verifying that sync is working

**Instead, you run one command:** `homelabctl bootstrap run`

---

## 🛠 **Prerequisites**

Before using the bootstrap engine, ensure you have:

| Requirement | Purpose | How to Check |
|-------------|---------|--------------|
| **Working Kubernetes cluster** | Target for bootstrap | `kubectl cluster-info` |
| **kubeconfig access** | Cluster authentication | `kubectl get nodes` |
| **Flux CLI ≥ 2.2** | Backend for operations | `flux --version` |
| **SSH key with repo access** | Git authentication | Key in `~/.ssh/id_ed25519` |
| **SOPS AGE key** | Secret decryption | Key in `~/.config/sops/age/keys.txt` |
| **Internet connectivity** | Download charts/images | Cluster can reach GitHub |

### 📋 **Quick Prerequisites Check**

```bash
# Verify cluster access
kubectl cluster-info
kubectl get nodes

# Verify Flux CLI
flux --version

# Check SSH key exists
ls -la ~/.ssh/id_ed25519*

# Check AGE key exists
ls -la ~/.config/sops/age/keys.txt

# Build homelabctl
task build-cli
# or: go build -o bin/homelabctl ./cmd/homelabctl
```

---

## 🚀 **Quick Start**

### 1. **Plan Your Bootstrap (Dry Run)**

Always start by seeing what the engine will do:

```bash
./bin/homelabctl bootstrap plan
```

**Expected Output:**
```
📋 Bootstrap execution plan for environment: home

Steps that would be executed:
  1. DetectCluster
  2. InstallFluxRuntime
  3. CreateSecrets
  4. FluxBootstrapGit
  5. VerifySync

Configuration:
  Repository: ssh://git@github.com/erauner12/homelab-k8s
  Branch: master
  Cluster Path: clusters/home/flux
  Environment: home
  Timeout: 30m0s
  Test Mode: false
```

### 2. **Run the Bootstrap**

Once you're ready, execute the full bootstrap:

```bash
./bin/homelabctl bootstrap run --kubeconfig ~/.kube/config
```

**What happens:** The engine executes all 5 steps automatically, with rollback on failure.

### 3. **Monitor Progress**

The engine provides detailed logging for each step:

```
🚀 Starting homelab bootstrap...
   Repository: ssh://git@github.com/erauner12/homelab-k8s
   Branch: master
   Path: clusters/home/flux
   Environment: home

INFO Executing step step=DetectCluster index=1 total=5
INFO Detecting cluster readiness
✅ Kubernetes API server is reachable
✅ Cluster nodes are ready ready_nodes=4 total_nodes=4
✅ CNI appears to be running

INFO Executing step step=InstallFluxRuntime index=2 total=5
INFO Installing Flux runtime components
✅ Flux runtime installed and ready

INFO Executing step step=CreateSecrets index=3 total=5
INFO Creating required secrets for Flux bootstrap
✅ SOPS AGE secret created
✅ Git deploy key secret created
🔑 Add this public key to your GitHub repository deploy keys: ssh-ed25519 AAAAC3Nz...

INFO Executing step step=FluxBootstrapGit index=4 total=5
INFO Performing Flux Git bootstrap
✅ Flux Git bootstrap completed successfully

INFO Executing step step=VerifySync index=5 total=5
INFO Verifying Flux sync status
✅ All Git sources are ready
✅ All Kustomizations are ready
✅ Flux sync verification completed successfully

=== Bootstrap Pipeline Summary ===
  DetectCluster: ✅ completed (2s)
  InstallFluxRuntime: ✅ completed (45s)
  CreateSecrets: ✅ completed (3s)
  FluxBootstrapGit: ✅ completed (30s)
  VerifySync: ✅ completed (120s)
===============================
```

---

## 🔧 **Configuration Options**

### **Basic Usage Patterns**

```bash
# Default home environment
./bin/homelabctl bootstrap run

# Specify different environment
./bin/homelabctl bootstrap run --environment cloud

# Custom repository
./bin/homelabctl bootstrap run --repo-url ssh://git@github.com/user/other-repo

# Different branch
./bin/homelabctl bootstrap run --branch main

# Custom cluster path
./bin/homelabctl bootstrap run --cluster-path clusters/production/flux

# Test mode (skips Talos-specific checks)
./bin/homelabctl bootstrap run --test-mode

# Non-interactive mode
./bin/homelabctl bootstrap run --non-interactive
```

### **Advanced Configuration**

```bash
# Custom SSH key
./bin/homelabctl bootstrap run --ssh-key ~/.ssh/custom_key

# Custom AGE key
./bin/homelabctl bootstrap run --age-key /path/to/age/keys.txt

# Specific kubeconfig
./bin/homelabctl bootstrap run --kubeconfig ~/.kube/staging-config

# Shorter timeout
./bin/homelabctl bootstrap run --timeout 10m
```

### **All Available Flags**

| Flag | Description | Default |
|------|-------------|---------|
| `--repo-url` | Git repository URL | `ssh://git@github.com/erauner12/homelab-k8s` |
| `--branch` | Git repository branch | `master` |
| `--cluster-path` | Path to cluster config in repo | `clusters/home/bootstrap` |
| `--ssh-key` | Path to SSH private key | `~/.ssh/id_ed25519` |
| `--age-key` | Path to SOPS AGE key file | `~/.config/sops/age/keys.txt` |
| `--kubeconfig` | Path to kubeconfig file | `$KUBECONFIG` or `~/.kube/config` |
| `--environment` | Target environment | `home` |
| `--timeout` | Overall timeout | `30m` |
| `--non-interactive` | Disable interactive prompts | `false` |
| `--test-mode` | Enable test mode | `false` |

---

## 🔍 **Troubleshooting**

### **Common Issues & Solutions**

#### **1. "No kubeconfig provided" Error**

```bash
Error: failed to build kubernetes client: invalid configuration: no configuration has been provided
```

**Root Cause:** The bootstrap engine's kubeconfig detection logic needs improvement. It tries in-cluster config first, then falls back, but doesn't properly detect the default kubeconfig location.

**Solution:** Always specify kubeconfig explicitly:
```bash
# Check current context
kubectl config current-context

# Run bootstrap with explicit kubeconfig (RECOMMENDED)
./bin/homelabctl bootstrap run --kubeconfig ~/.kube/config

# Or set environment variable
export KUBECONFIG=~/.kube/config
./bin/homelabctl bootstrap run
```

**Code Fix Needed:** The kubeconfig detection logic in `buildKubernetesClient()` should be improved to better handle default locations.

#### **2. "AGE key not found" Error**

```bash
Error: AGE key not found in standard locations and AgeKey option not specified
```

**Solution:** Create or specify AGE key:
```bash
# Generate new AGE key
age-keygen -o ~/.config/sops/age/keys.txt

# Or specify existing key
./bin/homelabctl bootstrap run --age-key /path/to/keys.txt
```

#### **3. "SSH key not found" Error**

```bash
Error: failed to read SSH private key: no such file or directory
```

**Solution:** Generate or specify SSH key:
```bash
# Generate new SSH key
ssh-keygen -t ed25519 -f ~/.ssh/id_ed25519

# Or specify existing key
./bin/homelabctl bootstrap run --ssh-key ~/.ssh/my_key
```

#### **4. Deploy Key Setup Required**

When you see this message:
```
🔑 Add this public key to your GitHub repository deploy keys: ssh-ed25519 AAAAC3Nz...
```

**Action needed:**
1. Copy the displayed public key
2. Go to your GitHub repo → Settings → Deploy keys
3. Click "Add deploy key"
4. Paste the key and **check "Allow write access"**
5. Save the deploy key

#### **5. Repository Protection Rules Blocking Push**

```bash
Error: ✗ failed to push manifests: failed to push to remote: command error on refs/heads/master: push declined due to repository rule violations
```

**Root Cause:** Branch protection rules or repository rulesets prevent direct pushes to master.

**Solution Options:**

**Option 1: Temporarily Disable Branch Protection (Recommended for Initial Setup)**

Before running bootstrap, temporarily disable branch protection rules:

```bash
# Check current protection
gh api repos/:owner/:repo/branches/master/protection

# Disable branch protection temporarily
gh api -X DELETE repos/:owner/:repo/branches/master/protection

# Check for repository rulesets
gh api repos/:owner/:repo/rulesets

# Disable rulesets if present (get ID from above command)
gh api -X PATCH repos/:owner/:repo/rulesets/RULESET_ID -f enforcement=disabled

# Now run bootstrap
./bin/homelabctl bootstrap run --kubeconfig ~/.kube/config

# Re-enable protection after successful bootstrap
# Example: Re-enable with basic protection
gh api -X PUT repos/:owner/:repo/branches/master/protection \
  --input - <<EOF
{
  "required_status_checks": null,
  "enforce_admins": false,
  "required_pull_request_reviews": {
    "dismiss_stale_reviews": true,
    "require_code_owner_reviews": false,
    "required_approving_review_count": 1
  },
  "restrictions": null,
  "allow_force_pushes": false,
  "allow_deletions": false
}
EOF
```

**Option 2: Configure Deploy Key Bypass (Production Approach)**

For production environments, configure branch protection to allow the deploy key:

```bash
# 1. Create deploy key with write access (done by bootstrap)
# 2. Configure branch protection to exempt the deploy key

# Get deploy key ID (after bootstrap creates it)
gh api repos/:owner/:repo/keys --jq '.[] | select(.title | contains("flux")) | .id'

# Update branch protection to allow deploy key bypasses
gh api -X PUT repos/:owner/:repo/branches/master/protection \
  --input - <<EOF
{
  "required_status_checks": null,
  "enforce_admins": false,
  "required_pull_request_reviews": {
    "dismiss_stale_reviews": true,
    "require_code_owner_reviews": false,
    "required_approving_review_count": 1,
    "bypass_pull_request_allowances": {
      "apps": ["flux-system"]
    }
  },
  "restrictions": null,
  "allow_force_pushes": false,
  "allow_deletions": false
}
EOF
```

**Option 3: Use a Bootstrap Branch (Alternative Workflow)**

Create a separate branch for bootstrap that merges automatically:

```bash
# Create bootstrap branch
git checkout -b bootstrap/initial-setup
git push origin bootstrap/initial-setup

# Run bootstrap targeting the bootstrap branch
./bin/homelabctl bootstrap run --branch bootstrap/initial-setup --kubeconfig ~/.kube/config

# After success, create PR and merge
gh pr create --title "Bootstrap Flux GitOps" --body "Initial Flux bootstrap"
gh pr merge --auto --merge
```

> **Note:** Future versions of homelabctl will include pre-flight checks for repository protection and guide you through the appropriate solution.

#### **6. Cluster Not Ready**

```bash
Error: cluster health check failed: no nodes are in Ready state
```

**Solution:** Fix cluster health first:
```bash
# Check node status
kubectl get nodes

# Check system pods
kubectl get pods --all-namespaces

# Check CNI (Cilium)
kubectl -n cilium get pods
```

#### **7. Flux Bootstrap Timeout**

```bash
Error: timeout waiting for Flux components to be ready after 5m0s
```

**Solution:** Check Flux pod status:
```bash
# Check Flux pods
kubectl -n flux-system get pods

# Check Flux logs
kubectl -n flux-system logs deployment/source-controller
kubectl -n flux-system logs deployment/kustomize-controller
```

#### **8. Flux Namespace Stuck in Terminating State**

```bash
Error: install failed: timeout waiting for: [Namespace/flux-system status: 'Terminating']
```

**Root Cause:** Previous Flux installation left GitRepository and Kustomization resources with finalizers, preventing namespace deletion.

**Solution:** Force cleanup stuck resources:

```bash
# Check what's preventing namespace deletion
kubectl get namespace flux-system -o yaml

# Check for stuck Flux resources
kubectl get gitrepositories.source.toolkit.fluxcd.io,kustomizations.kustomize.toolkit.fluxcd.io -n flux-system

# Remove finalizers from GitRepository
kubectl patch gitrepository flux-system -n flux-system -p '{"metadata":{"finalizers":[]}}' --type=merge

# Remove finalizers from Kustomization
kubectl patch kustomization flux-system -n flux-system -p '{"metadata":{"finalizers":[]}}' --type=merge

# Alternative: Force delete namespace with finalizer patch
kubectl get namespace flux-system -o json | jq '.spec.finalizers = []' | kubectl replace --raw "/api/v1/namespaces/flux-system/finalize" -f -

# Verify namespace is deleted
kubectl get namespace flux-system
# Should return: Error from server (NotFound): namespaces "flux-system" not found
```

**Pro Tip:** This same pattern applies to any stuck Kubernetes resources with finalizers. Always check for custom resources (CRDs) that might have finalizers preventing deletion.

### **🧪 Testing Without Real Cluster**

For development/testing, you can test the bootstrap planning without a cluster:

```bash
# This will show the plan but fail on DetectCluster (expected)
./bin/homelabctl bootstrap run --test-mode --timeout 5s
```

---

## 🏗 **Environment-Specific Usage**

### **Home Environment (Default)**

```bash
# Uses clusters/home/bootstrap path
./bin/homelabctl bootstrap run --environment home
```

### **Cloud Environment**

```bash
# Uses clusters/cloud/bootstrap path
./bin/homelabctl bootstrap run \
  --environment cloud \
  --cluster-path clusters/cloud/bootstrap
```

### **Kind (Local Testing)**

```bash
# Test mode skips Talos-specific checks
./bin/homelabctl bootstrap run \
  --environment kind \
  --test-mode \
  --timeout 10m
```

### **Custom Environment**

```bash
./bin/homelabctl bootstrap run \
  --environment staging \
  --cluster-path clusters/staging/bootstrap \
  --repo-url ssh://git@github.com/company/k8s-config
```

---

## 🔄 **Day 2 Operations**

### **Re-running Bootstrap (Idempotent)**

The bootstrap engine is idempotent - safe to run multiple times:

```bash
# Will skip steps that are already completed
./bin/homelabctl bootstrap run
```

Each step checks if work is already done:
- **DetectCluster**: Always runs (validates health)
- **InstallFluxRuntime**: Skips if Flux already installed
- **CreateSecrets**: Skips if secrets already exist
- **FluxBootstrapGit**: Skips if GitRepository/Kustomization exist
- **VerifySync**: Always runs (validates sync)

### **Resuming After Interruption**

> **Note:** Resume functionality is planned for future release.

```bash
# Currently shows placeholder
./bin/homelabctl bootstrap resume
# Error: resume functionality not yet implemented - please run 'bootstrap run' instead
```

For now, simply re-run the bootstrap - it will skip completed steps.

### **Cleanup (Planned)**

> **Note:** Cleanup functionality is planned for future release.

```bash
# Will be available in future version
./bin/homelabctl bootstrap cleanup
```

For now, use the manual cleanup process documented in [BOOTSTRAP.md](./BOOTSTRAP.md#nuke-everything-controllers-and-crds-and-start-fresh).

---

## 🆚 **Bootstrap Engine vs Manual Process**

| Aspect | Manual Process | Bootstrap Engine |
|--------|----------------|------------------|
| **Steps** | ~15 manual commands | 1 command |
| **Error Handling** | Manual recovery | Automatic rollback |
| **Idempotent** | ❌ (can fail on re-run) | ✅ (safe to re-run) |
| **Validation** | Manual checks | Built-in validation |
| **Secret Management** | Manual creation | Automated creation |
| **Progress Tracking** | Manual monitoring | Built-in logging |
| **Rollback** | Manual cleanup | Automatic rollback |
| **Documentation** | Complex runbook | Simple commands |

### **When to Use Manual Process**

The manual process (documented in [BOOTSTRAP.md](./BOOTSTRAP.md)) is still useful for:

- **Learning how Flux works** under the hood
- **Debugging complex issues** that require manual intervention
- **Custom environments** not supported by the engine
- **Air-gapped environments** where automation may not work

### **When to Use Bootstrap Engine**

Use the bootstrap engine for:

- **Production deployments** requiring reliability
- **CI/CD automation** where consistency matters
- **New cluster setup** where speed is important
- **Team environments** where you want to reduce human error
- **Standard configurations** matching supported patterns

---

## 🏃‍♂️ **Taskfile Integration**

The bootstrap engine integrates with the existing Taskfile:

```bash
# Plan bootstrap
task bootstrap:plan

# Run bootstrap
task bootstrap:run

# Bootstrap local Kind cluster
task bootstrap:kind

# Resume (placeholder)
task bootstrap:resume
```

These tasks automatically build the CLI and run the appropriate commands.

---

## 📚 **Next Steps**

After successful bootstrap:

1. **Verify Flux Status:**
   ```bash
   flux get sources git
   flux get kustomizations
   ```

2. **Monitor Application Rollout:**
   ```bash
   flux get helmreleases -A
   watch kubectl get pods -A
   ```

3. **Check Infrastructure Components:**
   ```bash
   kubectl get nodes
   kubectl -n network get pods -l app.kubernetes.io/name=envoy
   kubectl -n cert-manager get pods
   ```

4. **Review Day 2 Operations:**
   - See [BOOTSTRAP.md](./BOOTSTRAP.md#5-typical-day-two-commands) for ongoing management
   - Review monitoring and troubleshooting procedures
   - Set up automated reconciliation workflows

---

## 🤝 **Getting Help**

- **Bootstrap Engine Issues:** Check this guide's troubleshooting section
- **Manual Process:** See [BOOTSTRAP.md](./BOOTSTRAP.md) for detailed manual procedures
- **Flux Issues:** Consult [Flux documentation](https://fluxcd.io/docs/)
- **Cluster Issues:** See [TROUBLESHOOTING.md](./TROUBLESHOOTING.md)

---

## 🧪 **Bootstrap Engine Validation Results**

> **Testing Session:** Initial validation on fresh Talos cluster

### ✅ **What Works**
- **DetectCluster**: Successfully validates cluster health (4/4 nodes ready)
- **InstallFluxRuntime**: Flux controllers install and become ready (~17s)
- **CreateSecrets**: SOPS AGE and Git deploy key secrets created successfully
- **Idempotent Design**: Steps correctly skip when already completed
- **Error Handling**: Pipeline rollback works when steps fail

### ❌ **Issues Discovered**

1. **Kubeconfig Detection**: Requires explicit `--kubeconfig` flag, doesn't auto-detect `~/.kube/config`
2. **Repository Protection**: Cannot handle GitHub branch protection rules (common in production)
3. **Namespace Cleanup**: Gets stuck when Flux resources have finalizers
4. **CNI Detection**: Warns about missing CNI when Cilium isn't in expected namespace

### 🔧 **Required Fixes**

- [ ] Improve kubeconfig detection in `buildKubernetesClient()`
- [ ] Add repository protection handling (deploy keys or alternative workflows)
- [ ] Add automatic finalizer cleanup for stuck resources
- [ ] Better CNI detection logic for different CNI solutions
- [ ] Add pre-flight check for repository protection rules

### 💡 **Recommended Usage Until Fixed**

```bash
# Always use explicit kubeconfig and handle repo protection
./bin/homelabctl bootstrap run --kubeconfig ~/.kube/config --branch master
```

---
