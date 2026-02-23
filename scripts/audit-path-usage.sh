#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
INCLUDE_DOCS=false
SHOW_HITS=false

usage() {
  cat <<USAGE
Usage: $(basename "$0") [options] [path ...]

Audit whether repo paths are referenced by active entrypoints.

Options:
  --include-docs   Include docs/*.md and README.md as reference sources
  --show-hits      Show matching reference lines for each in-use path
  -h, --help       Show help

Examples:
  scripts/audit-path-usage.sh
  scripts/audit-path-usage.sh --show-hits
  scripts/audit-path-usage.sh infrastructure/cloudflared-apps operators/envoy-gateway
USAGE
}

PATHS=()
while [[ $# -gt 0 ]]; do
  case "$1" in
    --include-docs) INCLUDE_DOCS=true; shift ;;
    --show-hits) SHOW_HITS=true; shift ;;
    -h|--help) usage; exit 0 ;;
    *) PATHS+=("$1"); shift ;;
  esac
done

if ! command -v rg >/dev/null 2>&1; then
  echo "[ERR] ripgrep (rg) is required"
  exit 1
fi

cd "$ROOT_DIR"

if [[ ${#PATHS[@]} -eq 0 ]]; then
  while IFS= read -r d; do
    PATHS+=("$d")
  done < <(
    find apps components infrastructure operators security -mindepth 1 -maxdepth 1 -type d 2>/dev/null | sort
  )
  [[ -f "clusters/cloud/argocd/apps/kustomization.optional.yaml" ]] && PATHS+=("clusters/cloud/argocd/apps/kustomization.optional.yaml")
  [[ -f "clusters/cloud/argocd/operators/kustomization.optional.yaml" ]] && PATHS+=("clusters/cloud/argocd/operators/kustomization.optional.yaml")
fi

SOURCE_GLOBS=(
  "apps/**/*.yaml"
  "clusters/**/*.yaml"
  "components/**/*.yaml"
  "infrastructure/**/*.yaml"
  "operators/**/*.yaml"
  "scripts/**/*.sh"
  "security/**/*.yaml"
  "smoke/**/*.yaml"
  "Makefile"
  "Taskfile.yml"
)

if [[ "$INCLUDE_DOCS" == true ]]; then
  SOURCE_GLOBS+=("README.md" "docs/**/*.md")
fi

SOURCE_FILES=()
for g in "${SOURCE_GLOBS[@]}"; do
  while IFS= read -r f; do
    SOURCE_FILES+=("$f")
  done < <(rg --files -g "$g" 2>/dev/null || true)
done

if [[ ${#SOURCE_FILES[@]} -eq 0 ]]; then
  echo "[ERR] no source files found for audit"
  exit 1
fi

# Deduplicate source file list.
mapfile -t SOURCE_FILES < <(printf '%s\n' "${SOURCE_FILES[@]}" | sort -u)
# Avoid self-referential matches.
mapfile -t SOURCE_FILES < <(printf '%s\n' "${SOURCE_FILES[@]}" | rg -v '^scripts/audit-path-usage\.sh$' || true)

in_use=0
unused=0

echo "Path usage audit"
echo "Sources: apps/clusters/components/infrastructure/operators/security + scripts + smoke + Taskfile/Makefile$([[ "$INCLUDE_DOCS" == true ]] && echo " + docs")"
echo ""
printf '%-70s %-8s %s\n' "PATH" "STATUS" "MATCHES"
printf '%-70s %-8s %s\n' "----" "------" "-------"

for p in "${PATHS[@]}"; do
  hit_lines="$(rg -nF -- "$p" "${SOURCE_FILES[@]}" 2>/dev/null || true)"
  hit_count=0
  if [[ -n "$hit_lines" ]]; then
    hit_count="$(printf '%s\n' "$hit_lines" | wc -l | tr -d ' ')"
  fi

  if [[ "$hit_count" -gt 0 ]]; then
    in_use=$((in_use + 1))
    printf '%-70s %-8s %s\n' "$p" "in-use" "$hit_count"
    if [[ "$SHOW_HITS" == true ]]; then
      printf '%s\n' "$hit_lines" | sed 's/^/  - /'
    fi
  else
    unused=$((unused + 1))
    printf '%-70s %-8s %s\n' "$p" "unused" "0"
  fi
done

echo ""
echo "Summary: ${in_use} in-use | ${unused} unused"
