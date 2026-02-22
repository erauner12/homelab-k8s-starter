#!/usr/bin/env bash
set -euo pipefail

readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly NC='\033[0m'

readonly REQUIRED_TOOLS=(kubectl kustomize kubeconform helm age ssh-keygen gh jq)
readonly DEFAULT_SSH_KEY="$HOME/.ssh/id_ed25519"
readonly DEFAULT_AGE_KEY="$HOME/.config/sops/age/keys.txt"

errors=0

ok() { echo -e "${GREEN}[OK]${NC} $*"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $*"; }
err() { echo -e "${RED}[ERR]${NC} $*"; errors=$((errors+1)); }

echo "Running ArgoCD starter preflight checks"

for t in "${REQUIRED_TOOLS[@]}"; do
  command -v "$t" >/dev/null 2>&1 && ok "$t found" || err "$t missing"
done

kubectl cluster-info >/dev/null 2>&1 && ok "cluster reachable" || err "cluster not reachable"

if [[ -f "$DEFAULT_SSH_KEY" ]]; then
  ok "ssh key present: $DEFAULT_SSH_KEY"
else
  warn "ssh key missing: $DEFAULT_SSH_KEY"
fi

if [[ -f "$DEFAULT_AGE_KEY" ]]; then
  ok "age key present: $DEFAULT_AGE_KEY"
else
  warn "age key missing: $DEFAULT_AGE_KEY"
fi

gh auth status >/dev/null 2>&1 && ok "github auth ok" || err "github auth missing"

if [[ $errors -gt 0 ]]; then
  err "preflight failed with $errors error(s)"
  exit 1
fi

ok "preflight passed"
