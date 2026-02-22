#!/usr/bin/env bash
#
# Pre-Bootstrap Validation Script
# Validates environment is ready for Flux bootstrap
#
set -euo pipefail

# Colors for output
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly NC='\033[0m' # No Color

# Configuration
readonly REQUIRED_TOOLS=(kubectl flux age ssh-keygen gh jq)
readonly MIN_FLUX_VERSION="2.2.0"
readonly DEFAULT_SSH_KEY="$HOME/.ssh/id_ed25519"
readonly DEFAULT_AGE_KEY="$HOME/.config/sops/age/keys.txt"
readonly REPO_URL="${REPO_URL:-ssh://git@github.com/erauner/homelab-k8s}"
readonly BRANCH="${BRANCH:-master}"

# Results tracking
declare -A results
errors=0
warnings=0

# Helper functions
log_info() {
    echo -e "${GREEN}[INFO]${NC} $*"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $*"
    ((warnings++))
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $*"
    ((errors++))
}

check_pass() {
    echo -e "${GREEN}✓${NC} $*"
    results["$1"]="PASS"
}

check_fail() {
    echo -e "${RED}✗${NC} $*"
    results["$1"]="FAIL"
}

version_ge() {
    # Compare versions - returns 0 if $1 >= $2
    printf '%s\n%s' "$2" "$1" | sort -V -C
}

# Validation functions
check_tools() {
    log_info "Checking required tools..."

    for tool in "${REQUIRED_TOOLS[@]}"; do
        if command -v "$tool" &> /dev/null; then
            check_pass "tool_$tool" "$tool is installed"
        else
            check_fail "tool_$tool" "$tool is not installed"
            log_error "Install $tool before proceeding"
        fi
    done
}

check_flux_version() {
    log_info "Checking Flux version..."

    if ! command -v flux &> /dev/null; then
        check_fail "flux_version" "Flux CLI not found"
        return
    fi

    local version
    version=$(flux --version | awk '/flux version/ {print $3}' || echo "0.0.0")

    if version_ge "$version" "$MIN_FLUX_VERSION"; then
        check_pass "flux_version" "Flux version $version meets minimum requirement ($MIN_FLUX_VERSION)"
    else
        check_fail "flux_version" "Flux version $version is below minimum requirement ($MIN_FLUX_VERSION)"
        log_error "Upgrade Flux CLI: brew upgrade fluxcd/tap/flux"
    fi
}

check_kubernetes_access() {
    log_info "Checking Kubernetes cluster access..."

    if ! kubectl cluster-info &> /dev/null; then
        check_fail "k8s_access" "Cannot connect to Kubernetes cluster"
        log_error "Ensure kubeconfig is properly configured"
        return
    fi

    check_pass "k8s_access" "Connected to Kubernetes cluster"

    # Check nodes
    local ready_nodes
    ready_nodes=$(kubectl get nodes -o json | jq '[.items[] | select(.status.conditions[] | select(.type=="Ready" and .status=="True"))] | length')
    local total_nodes
    total_nodes=$(kubectl get nodes -o json | jq '.items | length')

    if [[ "$ready_nodes" -eq "$total_nodes" ]] && [[ "$total_nodes" -gt 0 ]]; then
        check_pass "k8s_nodes" "All nodes ready ($ready_nodes/$total_nodes)"
    else
        check_fail "k8s_nodes" "Not all nodes ready ($ready_nodes/$total_nodes)"
        kubectl get nodes
    fi
}

check_ssh_key() {
    log_info "Checking SSH key..."

    local ssh_key="${SSH_KEY:-$DEFAULT_SSH_KEY}"

    if [[ -f "$ssh_key" ]]; then
        check_pass "ssh_key" "SSH key found at $ssh_key"

        # Check key permissions
        local perms
        perms=$(stat -c "%a" "$ssh_key" 2>/dev/null || stat -f "%Lp" "$ssh_key" 2>/dev/null || echo "000")
        if [[ "$perms" == "600" ]] || [[ "$perms" == "400" ]]; then
            check_pass "ssh_key_perms" "SSH key has correct permissions ($perms)"
        else
            check_fail "ssh_key_perms" "SSH key has incorrect permissions ($perms, should be 600)"
            log_warn "Fix with: chmod 600 $ssh_key"
        fi
    else
        check_fail "ssh_key" "SSH key not found at $ssh_key"
        log_error "Generate with: ssh-keygen -t ed25519 -f $ssh_key"
    fi
}

check_age_key() {
    log_info "Checking SOPS AGE key..."

    local age_key="${AGE_KEY:-$DEFAULT_AGE_KEY}"

    if [[ -f "$age_key" ]]; then
        check_pass "age_key" "AGE key found at $age_key"

        # Validate key format
        if grep -q "AGE-SECRET-KEY" "$age_key"; then
            check_pass "age_key_valid" "AGE key appears valid"
        else
            check_fail "age_key_valid" "AGE key file exists but doesn't contain valid key"
        fi
    else
        check_fail "age_key" "AGE key not found at $age_key"
        log_error "Generate with: age-keygen -o $age_key"
    fi
}

check_github_access() {
    log_info "Checking GitHub repository access..."

    # Extract owner and repo from URL
    local owner repo
    if [[ "$REPO_URL" =~ github\.com[:/]([^/]+)/([^/.]+)(\.git)?$ ]]; then
        owner="${BASH_REMATCH[1]}"
        repo="${BASH_REMATCH[2]}"
    else
        check_fail "github_url" "Cannot parse GitHub repository from URL: $REPO_URL"
        return
    fi

    # Check if gh is authenticated
    if ! gh auth status &> /dev/null; then
        check_fail "github_auth" "GitHub CLI not authenticated"
        log_error "Authenticate with: gh auth login"
        return
    fi

    check_pass "github_auth" "GitHub CLI authenticated"

    # Check repository access
    if gh api "repos/$owner/$repo" &> /dev/null; then
        check_pass "github_repo" "Can access repository $owner/$repo"
    else
        check_fail "github_repo" "Cannot access repository $owner/$repo"
        return
    fi

    # Check branch protection
    log_info "Checking branch protection rules..."

    if gh api "repos/$owner/$repo/branches/$BRANCH/protection" &> /dev/null; then
        check_fail "branch_protection" "Branch $BRANCH has protection rules enabled"
        log_warn "You will need to temporarily disable protection or use an alternative bootstrap method"
        log_warn "See: docs/BOOTSTRAP_ENGINE.md#repository-protection-rules-blocking-push"
    else
        check_pass "branch_protection" "Branch $BRANCH has no protection rules"
    fi

    # Check for existing deploy keys
    local deploy_keys
    deploy_keys=$(gh api "repos/$owner/$repo/keys" | jq length)
    if [[ "$deploy_keys" -gt 0 ]]; then
        log_info "Found $deploy_keys existing deploy key(s)"
    fi
}

check_flux_namespace() {
    log_info "Checking for existing Flux installation..."

    if kubectl get namespace flux-system &> /dev/null; then
        check_fail "flux_namespace" "flux-system namespace already exists"
        log_warn "Existing Flux installation detected"

        # Check if it's stuck terminating
        local phase
        phase=$(kubectl get namespace flux-system -o jsonpath='{.status.phase}' 2>/dev/null || echo "Unknown")
        if [[ "$phase" == "Terminating" ]]; then
            log_error "Namespace is stuck in Terminating state"
            log_error "See: docs/BOOTSTRAP_ENGINE.md#flux-namespace-stuck-in-terminating-state"
        fi
    else
        check_pass "flux_namespace" "No existing Flux installation found"
    fi
}

check_network_connectivity() {
    log_info "Checking network connectivity..."

    # Check DNS resolution
    if host github.com &> /dev/null || nslookup github.com &> /dev/null; then
        check_pass "dns" "DNS resolution working"
    else
        check_fail "dns" "DNS resolution failing"
    fi

    # Check GitHub connectivity
    if curl -s -o /dev/null -w "%{http_code}" https://api.github.com | grep -q "200"; then
        check_pass "github_api" "Can reach GitHub API"
    else
        check_fail "github_api" "Cannot reach GitHub API"
    fi
}

generate_summary() {
    echo
    echo "===== Pre-Bootstrap Validation Summary ====="
    echo

    local total_checks=0
    local passed_checks=0

    for check in "${!results[@]}"; do
        ((total_checks++))
        if [[ "${results[$check]}" == "PASS" ]]; then
            ((passed_checks++))
        fi
    done

    echo "Total checks: $total_checks"
    echo "Passed: $passed_checks"
    echo "Failed: $((total_checks - passed_checks))"
    echo "Warnings: $warnings"
    echo

    if [[ "$errors" -eq 0 ]]; then
        echo -e "${GREEN}✓ Environment is ready for bootstrap!${NC}"
        echo
        echo "Next steps:"
        echo "1. Run: ./bin/homelabctl bootstrap plan"
        echo "2. Review the plan"
        echo "3. Run: ./bin/homelabctl bootstrap run --kubeconfig ~/.kube/config"
        return 0
    else
        echo -e "${RED}✗ Environment is not ready for bootstrap${NC}"
        echo
        echo "Fix the errors above before proceeding."
        return 1
    fi
}

# Main execution
main() {
    echo "🔍 Running pre-bootstrap validation..."
    echo "Repository: $REPO_URL"
    echo "Branch: $BRANCH"
    echo

    check_tools
    check_flux_version
    check_kubernetes_access
    check_ssh_key
    check_age_key
    check_github_access
    check_flux_namespace
    check_network_connectivity

    generate_summary
}

# Run main function
main "$@"
