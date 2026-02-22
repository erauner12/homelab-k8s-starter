# Max Starter Repo Porting Plan

This plan is generated from all tracked files in this repository (`git ls-files`).

## Artifacts

- File-by-file matrix: `docs/porting/max-file-inventory.csv`
- This execution plan: `docs/porting/max-porting-plan.md`

## Classification Legend

- `PORT_CORE`: copy now
- `PORT_CORE_ADAPT`: copy now, then replace environment-specific values
- `PORT_TEMPLATE_ADAPT`: use as a template reference
- `PORT_OPTIONAL`: defer
- `PORT_OPTIONAL_PHASE2`: phase-2 migration target
- `PORT_OPTIONAL_OBSERVABILITY`: optional monitoring stack
- `PORT_OPTIONAL_TOOLING`: optional Go CLI tooling
- `PORT_OPTIONAL_VALIDATION`: optional validators
- `EXCLUDE_PROPRIETARY_RECREATE`: never copy; recreate in target repo
- `EXCLUDE_APP_SPECIFIC`: app not in minimal scope
- `EXCLUDE_PLATFORM_SPECIFIC`: CI/automation not needed in starter repo
- `EXCLUDE_OUT_OF_SCOPE`: not needed for first cut

## Execution Phases

1. Phase 0: Scaffold new repo with directories `deploy/`, `infra/`, `security/`, `operators/`, `apps/`.
2. Phase 1: Port all `PORT_CORE` and `PORT_CORE_ADAPT` files for ArgoCD + cert-manager + external-secrets + tailscale + longhorn-config + external-dns + demo app.
3. Phase 2: Recreate all `EXCLUDE_PROPRIETARY_RECREATE` files as new secrets/tokens for Max's GitHub, Cloudflare, and Tailscale accounts.
4. Phase 3: Bootstrap cluster and validate with demo app sync + health checks.
5. Phase 4: Add `PORT_OPTIONAL_OBSERVABILITY` (Grafana stack) and `PORT_OPTIONAL_PHASE2` (openclaw) after baseline is stable.
6. Phase 5: Add optional validation and automation from `PORT_OPTIONAL_VALIDATION` and `PORT_OPTIONAL_TOOLING` if desired.

## Required Environment Replacements

- Git repository URLs (`erauner/homelab-k8s` -> Max repo)
- Domains (`erauner.dev` -> Max domain)
- Namespace/domain-specific labels
- Cloudflare API token secret references
- Tailscale OAuth client credentials and tags
- Any `*.sops.yaml` values

## Counts by Action

- EXCLUDE_APP_SPECIFIC: 778
- EXCLUDE_OUT_OF_SCOPE: 368
- EXCLUDE_PLATFORM_SPECIFIC: 533
- EXCLUDE_PROPRIETARY_RECREATE: 123
- PORT_CORE: 76
- PORT_CORE_ADAPT: 207
- PORT_OPTIONAL: 551
- PORT_OPTIONAL_OBSERVABILITY: 62
- PORT_OPTIONAL_PHASE2: 33
- PORT_OPTIONAL_TOOLING: 29
- PORT_OPTIONAL_VALIDATION: 22
- PORT_TEMPLATE_ADAPT: 9
