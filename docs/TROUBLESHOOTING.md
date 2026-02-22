# Common Deployment Issues & Solutions

This document captures common issues encountered during application deployments and their solutions.

## Kustomize Issues

### 1. Patch Format Errors

**Problem**: `error validating data: ValidationError: invalid value: map[string]interface{}`

**Common Causes**:
- Missing `target` specification in patches
- Incorrect YAML structure for strategic merge patches
- Using JSON Patch format where strategic merge is expected

**Solution**:
```yaml
# ✅ Correct patch format
patches:
  - path: my-patch.yaml
    target:
      kind: HelmRelease
      name: my-app

# ❌ Incorrect - missing target
patches:
  - path: my-patch.yaml
```

### 2. Environment Variable Substitution

**Problem**: Variables like `$(VAR_NAME)` not being substituted

**Root Cause**: Kustomize variable substitution has limitations in HelmRelease values

**Solutions**:
1. Use hardcoded values when possible
2. Use explicit JSON patches for dynamic values
3. Validate builds with `kustomize build` before committing

## CloudNativePG Issues

### 1. Service Name References

**Problem**: Connection errors to PostgreSQL database

**Root Cause**: CNPG creates multiple services with specific suffixes:
- `CLUSTER_NAME-rw` - Read/Write service
- `CLUSTER_NAME-ro` - Read-Only service
- `CLUSTER_NAME-r` - Read service

**Solution**: Always use the `-rw` service for applications that need write access.

### 2. Schema Validation Errors

**Problem**: `monitoring` block causes validation errors

**Solution**: Comment out or remove monitoring configuration until schema is updated:
```yaml
spec:
  # monitoring:
  #   enabled: true
```

## External-DNS Issues

### 1. DNS Records Not Created

**Problem**: IngressRoute exists but DNS records aren't created

**Debug Steps**:
1. Check external-dns logs: `kubectl logs -n network deployment/external-dns-cloudflare`
2. Verify domain filters match your domain
3. Check IngressRoute annotations:
   ```yaml
   annotations:
     external-dns.alpha.kubernetes.io/hostname: subdomain.yourdomain.com
     external-dns.alpha.kubernetes.io/target: tunnel.yourdomain.com
   ```

### 2. Environment Variable Issues

**Problem**: `$(CF_DOMAINS)` not resolving

**Solution**: Use hardcoded domain filters in external-dns configuration.

## App-Template Issues

### 1. Ingress Disable Patch

**Problem**: `ingress.enabled: false` doesn't work with newer versions

**Solution**: Use `main.enabled: false` for app-template v3.7.3+:
```yaml
- op: add
  path: /spec/values/ingress/main/enabled
  value: false
```

## Prevention Strategies

### 1. Pre-commit Validation
- Always run `kustomize build` before committing
- Use `pre-commit` hooks to catch issues early

### 2. Component Reuse
- Use standardized components for common patterns
- Avoid duplicating configuration across overlays

### 3. Progressive Testing
- Test base configurations before adding overlays
- Validate each layer incrementally

### 4. Monitoring Integration
- Monitor external-dns logs for DNS issues
- Set up alerts for failed HelmRelease deployments

## Variable Validation Script

To prevent the type of deployment issues we encountered with unresolved variable substitutions, use the validation script:

### Quick Usage
```bash
# Run validation manually
./scripts/validate-variables.sh

# Run via Taskfile
task validate:variables

# Include in pre-commit checks
task pre-commit
```

### What It Checks
- **Unresolved variables** like `$(CF_DOMAINS)` that can cause silent failures
- **External-DNS configuration** - catches the specific issues we encountered
- **Kustomize builds** - validates all kustomizations build successfully
- **Problematic patterns** - detects common variable substitution mistakes

### Integration Options
```bash
# Option 1: Use existing pre-commit task (includes variable validation)
task pre-commit

# Option 2: Install as git pre-commit hook
cp hooks/pre-commit-variables .git/hooks/pre-commit
chmod +x .git/hooks/pre-commit

# Option 3: Manual validation before committing
./scripts/validate-variables.sh && git commit
```

This script would have immediately caught the external-DNS variable substitution issue that caused our deployment problems!
