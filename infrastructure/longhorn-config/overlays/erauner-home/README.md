# Longhorn Post-Installation Configuration

## Important: Longhorn Installation is Managed by Talos

Longhorn storage is installed at the Talos/Omni layer via inline manifests, NOT through Flux/GitOps.

### What This Directory Contains

This directory ONLY contains post-installation configurations that require:
- Flux for GitOps management
- SOPS for secret decryption
- Other cluster services (Traefik, cert-manager)

**Files in this directory:**
- `backup-secret.sops.yaml` - MinIO S3 backup credentials (SOPS encrypted)
- `backup-secret-idrive.sops.yaml` - IDrive E2 backup credentials (SOPS encrypted)
- `dashboard-ingressroute.yaml` - Traefik routing for Longhorn UI
- `certificate.yaml` - TLS certificate for dashboard access

### What's NOT Here

- ❌ HelmRelease or HelmChart definitions
- ❌ Namespace creation (handled by Talos)
- ❌ Longhorn installation manifests
- ❌ CRD resources (moved to `../longhorn-config/`)

### Related Directories

- `../longhorn-config/` - Contains Longhorn CRD resources (recurring jobs, backup targets)
- `../../../clusters/home/flux/kustomization-longhorn-config.yaml` - Flux kustomization for CRD resources

### Talos Installation Details

See the Omni cluster configuration for Longhorn installation:
- Installation manifest: `omni/patches/longhorn-install-home.yaml`
- Configuration manifest: `omni/patches/longhorn-configure-home.yaml`

### Why This Separation?

1. **Talos/Omni Layer**: Handles core storage installation as part of cluster bootstrap
2. **Flux/GitOps Layer**: Manages day-2 operations, secrets, and integrations

This ensures storage is available immediately when the cluster boots, before Flux is even installed.
