# ArgoCD App-of-Apps Automation Setup

This document describes the automation setup for ArgoCD app-of-apps pattern to eliminate manual sync requirements.

## What Was Implemented

### 1. Parent App Configuration
- **Recursive directory watching**: Parent now watches `argocd-apps/applications/*.yaml` for changes
- **ApplyOutOfSyncOnly**: Reduces unnecessary re-syncs of unchanged children
- **Location**: `argocd-apps/base/app-of-apps.yaml`

### 2. GitHub Webhook Integration
- **HTTPRoute**: Exposes `/api/webhook` endpoint at `https://argocd.erauner.dev/api/webhook`
- **Secret Management**: Using 1Password via ExternalSecret (follows proven login item pattern)
- **Terraform**: `terraform/onepassword/argocd.tf` manages the webhook secret
- **Location**: `infrastructure/base/argo-ecosystem/argocd/httproute-webhook.yaml`

### 3. Manual Refresh Script
- **Script**: `hack/argocd-refresh.sh` - Forces parent refresh and optional child sync
- **Makefile Target**: `make argocd-refresh [APP=appname]`
- **Usage Examples**:
  ```bash
  # Refresh parent and all children
  make argocd-refresh

  # Refresh parent and sync specific child
  make argocd-refresh APP=renovate
  ```

### 4. Faster Reconciliation (Safety Net)
- **ConfigMap**: Sets 60s reconciliation with 15s jitter
- **Location**: `infrastructure/base/argo-ecosystem/argocd/argocd-cm-patch.yaml`

### 5. Multi-Source Documentation
- **Documentation**: `docs/gitops/argocd-multi-source.md` - Explains the "$values ref" gotcha
- **Inline Comments**: All multi-source Applications now have clarifying comments

## Setup Instructions

### 1. Create 1Password Item
```bash
cd terraform/onepassword
terraform apply -target=onepassword_item.argocd_webhook_secret
```

### 2. Configure GitHub Webhook
1. Go to repository Settings → Webhooks → Add webhook
2. Configure:
   - **Payload URL**: `https://argocd.erauner.dev/api/webhook`
   - **Content type**: `application/json`
   - **Secret**: (copy from 1Password item "ArgoCD - GitHub Webhook Secret")
   - **Events**: Select "Push" events

### 3. Apply Changes
```bash
git add -A
git commit -m "feat: automate ArgoCD app-of-apps sync with webhooks and multi-source docs"
git push
```

## How It Works

### Automatic Flow (via webhook)
1. Developer pushes changes to GitHub
2. GitHub sends webhook to ArgoCD at `/api/webhook`
3. ArgoCD refreshes repository cache
4. Parent app (with `directory.recurse: true`) detects child spec changes
5. Parent auto-syncs (via `automated.selfHeal: true`)
6. Updated child Applications auto-sync themselves

### Manual Flow (when needed)
```bash
# Force refresh everything
make argocd-refresh

# Force refresh and sync specific app
make argocd-refresh APP=renovate
```

## Multi-Source Gotcha Prevention

All multi-source Applications now include this warning comment:
```yaml
# Git source ONLY for Helm value files.
# IMPORTANT: do not set `path:` here; this source should NOT render manifests.
- repoURL: git@github.com:erauner/homelab-k8s.git
  targetRevision: master
  ref: values  # <-- NO path field!
```

This prevents the common mistake of adding `path: .` to a ref-only source, which causes ArgoCD to try rendering the entire repo as manifests.

## Troubleshooting

### Webhook Not Working
1. Check webhook secret matches in GitHub and 1Password
2. Verify HTTPRoute is applied: `kubectl get httproute -n argocd`
3. Check ArgoCD logs: `kubectl logs -n argocd -l app.kubernetes.io/name=argocd-server`

### Parent Not Detecting Changes
1. Verify `directory.recurse: true` in parent app
2. Check parent sync policy has `automated.selfHeal: true`
3. Force refresh: `make argocd-refresh`

### Multi-Source Issues
1. Ensure ref-only sources have NO `path:` field
2. Check documentation: `docs/gitops/argocd-multi-source.md`
3. Verify with: `argocd app get <app> -o json | jq '.spec.sources'`
