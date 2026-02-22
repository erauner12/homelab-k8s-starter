# Bootstrap Quick Start Guide

A concise reference for bootstrapping ArgoCD GitOps on your homelab cluster.

## 🚀 Quick Bootstrap (5 minutes)

```bash
# 1. Validate environment (30 seconds)
./scripts/pre-bootstrap-test.sh

# 2. Build CLI if needed (30 seconds)
task build-cli

# 3. Check bootstrap plan (10 seconds)
./bin/homelabctl bootstrap plan

# 4. Run bootstrap (3-4 minutes)
./bin/homelabctl bootstrap run --kubeconfig ~/.kube/config
```

## 📋 Pre-flight Checklist

- [ ] Kubernetes cluster is running (`kubectl get nodes`)
- [ ] SSH key exists (`ls ~/.ssh/id_ed25519`)
- [ ] AGE key exists (`ls ~/.config/sops/age/keys.txt`)
- [ ] GitHub access works (`gh auth status`)
- [ ] Branch protection disabled (if applicable)

## 🔧 Common Fixes

### Missing SSH Key
```bash
ssh-keygen -t ed25519 -f ~/.ssh/id_ed25519
```

### Missing AGE Key
```bash
age-keygen -o ~/.config/sops/age/keys.txt
```

### GitHub CLI Not Authenticated
```bash
gh auth login
```

### Disable Branch Protection (Temporary)
```bash
# Check current protection
gh api repos/:owner/:repo/branches/master/protection

# Disable protection
gh api -X DELETE repos/:owner/:repo/branches/master/protection

# Run bootstrap
./bin/homelabctl bootstrap run --kubeconfig ~/.kube/config

# Re-enable protection (see BOOTSTRAP_ENGINE.md for full command)
```

### Flux Namespace Stuck
```bash
# Remove finalizers from stuck resources
kubectl patch gitrepository flux-system -n flux-system -p '{"metadata":{"finalizers":[]}}' --type=merge
kubectl patch kustomization flux-system -n flux-system -p '{"metadata":{"finalizers":[]}}' --type=merge

# Force delete namespace
kubectl get namespace flux-system -o json | jq '.spec.finalizers = []' | kubectl replace --raw "/api/v1/namespaces/flux-system/finalize" -f -
```

## 🎯 Bootstrap Options

### Default (Home Environment)
```bash
./bin/homelabctl bootstrap run --kubeconfig ~/.kube/config
```

### Cloud Environment
```bash
./bin/homelabctl bootstrap run \
  --environment cloud \
  --cluster-path clusters/cloud/bootstrap \
  --kubeconfig ~/.kube/config
```

### Test Mode (Kind/Local)
```bash
./bin/homelabctl bootstrap run \
  --test-mode \
  --environment kind \
  --kubeconfig ~/.kube/config
```

### Custom Repository
```bash
./bin/homelabctl bootstrap run \
  --repo-url ssh://git@github.com/youruser/yourrepo \
  --branch main \
  --kubeconfig ~/.kube/config
```

## ✅ Post-Bootstrap Verification

```bash
# Check Flux components
flux get sources git
flux get kustomizations

# Watch application rollout
watch flux get helmreleases -A

# Check critical services
kubectl -n network get pods -l app.kubernetes.io/name=envoy
kubectl -n cert-manager get pods
kubectl -n longhorn-system get pods
```

## 🔄 Day 2 Operations

### Force Reconciliation
```bash
# Reconcile specific kustomization
flux reconcile kustomization flux-system

# Reconcile all kustomizations
flux reconcile kustomization --all
```

### Check Sync Status
```bash
# Overall status
flux get all

# Detailed kustomization status
flux get kustomizations -o wide
```

### Suspend/Resume
```bash
# Suspend a kustomization
flux suspend kustomization <name>

# Resume a kustomization
flux resume kustomization <name>
```

## 🚨 Emergency Procedures

### Complete Flux Removal
```bash
# Uninstall Flux keeping namespace
flux uninstall --silent

# Remove namespace and all resources
flux uninstall --namespace=flux-system

# Manual cleanup if needed
kubectl delete namespace flux-system --force --grace-period=0
```

### Re-bootstrap After Failure
```bash
# Clean up first
flux uninstall --namespace=flux-system

# Wait for cleanup
kubectl get namespace flux-system

# Re-run bootstrap
./bin/homelabctl bootstrap run --kubeconfig ~/.kube/config
```

## 📚 More Information

- Full bootstrap guide: [BOOTSTRAP_ENGINE.md](./BOOTSTRAP_ENGINE.md)
- Manual process: [BOOTSTRAP.md](./BOOTSTRAP.md)
- Troubleshooting: [TROUBLESHOOTING.md](./TROUBLESHOOTING.md)
- Dependency management: [kustomization-dependencies.md](./kustomization-dependencies.md)
