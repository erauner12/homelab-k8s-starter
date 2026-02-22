#!/usr/bin/env bash
set -euo pipefail
# Ensure xtrace output goes to stderr, not stdout (prevents readarray breakage)
export BASH_XTRACEFD=2

# Enhanced Flux reconciliation script with proper dependency ordering
#
# This script reconciles Flux kustomizations in the correct dependency order to avoid
# revision mismatches and dependency failures that can occur when reconciling in parallel
# or without considering the dependency chain.
#
# Dependency Order Explanation:
# 1. Git Source: Must be reconciled first to fetch latest changes
# 2. Infrastructure: Base infrastructure components (namespaces, controllers, networking)
# 3. Policies: Kyverno and other admission control policies (MUST come before apps for mutation/validation)
# 4. Database Controllers: CloudNativePG and other database operators
# 5. Database Instances: Individual database clusters that depend on controllers
# 6. Applications: Apps that depend on databases and infrastructure
#
# This ordering prevents common issues like:
# - "dependency revision is not up to date" errors
# - "namespace not found" errors when apps deploy before infrastructure
# - Database connection failures when apps start before databases are ready
# - Policy violations when apps deploy without admission control policies active

# Color output for better readability
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Helper functions
log_info() {
    echo -e "${BLUE}ℹ️  $1${NC}" >&2
}

log_success() {
    echo -e "${GREEN}✅ $1${NC}" >&2
}

log_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}" >&2
}

log_error() {
    echo -e "${RED}❌ $1${NC}" >&2
}

log_section() {
    echo -e "\n${YELLOW}📋 $1${NC}" >&2
    echo "==================================================" >&2
}

log_debug() {
    if [[ "${DEBUG:-}" == "1" ]] || [[ "${VERBOSE:-}" == "true" ]]; then
        echo -e "${BLUE}🐛 DEBUG: $1${NC}" >&2
    fi
}

# Function to check for orphaned resources from old kustomizations
check_orphaned_resources() {
    log_section "🔍 Checking for orphaned resources from removed kustomizations"

    local old_kustomizations=(
        "home-apps"
        "home-authelia-db-prod"
        "home-gitea-db-prod"
        "home-vikunja-db-prod"
        "home-homepage-prod"
    )

    local found_orphans=false

    for ks_name in "${old_kustomizations[@]}"; do
        log_debug "Checking for resources labeled with kustomize.toolkit.fluxcd.io/name=$ks_name"

        # Check for any resources with this kustomization label
        local resources
        resources=$(kubectl get all --all-namespaces \
            -l "kustomize.toolkit.fluxcd.io/name=$ks_name" \
            --ignore-not-found \
            -o custom-columns=KIND:.kind,NAMESPACE:.metadata.namespace,NAME:.metadata.name \
            --no-headers 2>/dev/null || echo "")

        if [[ -n "$resources" ]]; then
            if [[ "$found_orphans" == "false" ]]; then
                log_warning "Found orphaned resources from removed kustomizations:"
                found_orphans=true
            fi

            log_warning "  From $ks_name:"
            echo "$resources" | while read -r line; do
                log_warning "    $line"
            done
        else
            log_debug "No orphaned resources found for $ks_name"
        fi
    done

    if [[ "$found_orphans" == "false" ]]; then
        log_success "No orphaned resources found from old kustomizations"
    else
        log_warning "Consider pruning orphaned resources with 'flux prune kustomization -n flux-system <name>' or manual cleanup"
    fi
}

# Function to reconcile with retry logic
reconcile_with_retry() {
    local resource_type="$1"
    local resource_name="$2"
    local max_retries=3
    local retry_count=0

    while [ $retry_count -lt $max_retries ]; do
        log_info "Reconciling $resource_type: $resource_name (attempt $((retry_count + 1))/$max_retries)"

        if flux reconcile "$resource_type" "$resource_name" --namespace flux-system; then
            log_success "$resource_type $resource_name reconciled successfully"
            return 0
        else
            retry_count=$((retry_count + 1))
            if [ $retry_count -lt $max_retries ]; then
                log_warning "Reconciliation failed, retrying in 5 seconds..."
                sleep 5
            fi
        fi
    done

    log_error "Failed to reconcile $resource_type $resource_name after $max_retries attempts"
    return 1
}

# Function to check kustomization health
check_kustomization_health() {
    local name="$1"
    local status
    status=$(kubectl get kustomization "$name" -n flux-system -o jsonpath='{.status.conditions[?(@.type==\"Ready\")].status}' 2>/dev/null || echo "NotFound")

    if [ "$status" = "True" ]; then
        log_success "Kustomization $name is healthy"
        return 0
    else
        log_warning "Kustomization $name is not ready (status: $status)"
        return 1
    fi
}

# Parse command line arguments
SPECIFIC_KUSTOMIZATIONS=()
RECONCILE_ALL=false
VERBOSE=false

# Process arguments to separate flags from kustomization names
while [[ $# -gt 0 ]]; do
    case $1 in
        --help|-h)
            cat << EOF
Enhanced Flux Reconciliation Script

Usage: $0 [OPTIONS] [kustomization-names...]

Options:
  --verbose, -v               Enable verbose output for troubleshooting
  --help, -h                  Show this help message

Examples:
  $0                           # Reconcile all kustomizations in dependency order
  $0 --verbose                 # Reconcile all with verbose output
  $0 home-infra               # Reconcile only infrastructure
  $0 home-infra home-apps     # Reconcile infrastructure and apps
  $0 --verbose home-infra     # Reconcile infrastructure with verbose output

Environment Variables:
  DEBUG=1                     # Enable debug output for troubleshooting
  CHECK_ORPHANS=1             # Check for orphaned resources from removed kustomizations

Available kustomizations:
  Infrastructure: home-infra-controllers, home-infra-configs
  Policies:       home-kyverno-policies
  Databases:      cluster-controllers-cloudnative-pg
  Stacks:         (auto-discovered from homelab.dev/layer=stack labels)

The script automatically handles:
- Git source reconciliation
- Auto-discovery of kustomizations via cluster labels
- Proper dependency ordering by layer (infra -> policy -> stack)
- Automatic skipping of suspended kustomizations
- Retry logic for failed reconciliations
- Health checking and status reporting
- Color-coded output for better readability

Note: Auto-discovery requires cluster access. Falls back to static list if unavailable.
EOF
            exit 0
            ;;
        --verbose|-v)
            VERBOSE=true
            shift
            ;;
        -*)
            log_error "Unknown option: $1"
            echo "Use --help for usage information"
            exit 1
            ;;
        *)
            # This is a kustomization name
            SPECIFIC_KUSTOMIZATIONS+=("$1")
            shift
            ;;
    esac
done

# After determining if reconciling all or specific kustomizations
if [ ${#SPECIFIC_KUSTOMIZATIONS[@]} -eq 0 ]; then
    RECONCILE_ALL=true
fi

# Debug initial argument parsing state
log_debug "Initial state: SPECIFIC_KUSTOMIZATIONS=(${SPECIFIC_KUSTOMIZATIONS[*]})"
log_debug "Initial state: RECONCILE_ALL=$RECONCILE_ALL"
log_debug "Initial state: VERBOSE=$VERBOSE"

# Define dependency-ordered kustomization groups
# Order matters! Dependencies must come before dependents
INFRASTRUCTURE_KUSTOMIZATIONS=(
    "flux-system"                           # Core Flux components
    "home-infra-controllers"               # Base infrastructure controllers
    "home-infra-configs"                   # Infrastructure configs (depends on controllers)
)

DATABASE_KUSTOMIZATIONS=(
    "cluster-controllers-cloudnative-pg"   # Database operators
    # Individual DB instances are managed within stack kustomizations but may be standalone
    "home-authelia-db-prod"
    "home-gitea-db-prod"
    "home-vikunja-db-prod"
)

APPLICATION_KUSTOMIZATIONS=(
    # Stack kustomizations that manage their own dependencies
    "home-authelia-stack"
    "home-gitea-stack"
    "home-vikunja-stack"
    "home-homepage-prod"
    "home-homepage-staging"
    "home-apps"                            # Apps umbrella (mostly empty now)
)

POLICY_KUSTOMIZATIONS=(
    # CRITICAL: Admission control policies MUST be reconciled before applications!
    # Kyverno policies with mutation rules (like lb-pool auto-injection) need to be
    # active before services are created, otherwise HelmReleases can get stuck.
    "home-kyverno-policies"
)

# Function to discover kustomizations from cluster labels
discover_kustomizations() {
    log_debug "Running discover_kustomizations from $(pwd)"
    log_info "Auto-discovering kustomizations from cluster labels..."

    # Query cluster for kustomizations with homelab.dev/layer labels in dependency order
    local discovered_kustomizations=()

    # Try to get from cluster, fall back to static list if cluster unavailable
    if kubectl get kustomizations -n flux-system >/dev/null 2>&1; then
        # Get kustomizations grouped by layer, sorted by layer then name
        local layer_order=("infra" "policy" "stack")

        for layer in "${layer_order[@]}"; do
            log_debug "Discovering kustomizations for layer: ${layer}"

            # Use -o name which gives reliable output, then extract just the name part
            local layer_kustomizations
            layer_kustomizations=$(kubectl get kustomizations -n flux-system \
                -l "homelab.dev/layer=${layer}" \
                -o name 2>/dev/null | \
                sed 's|kustomization.kustomize.toolkit.fluxcd.io/||' | \
                sort)

            if [[ -n "$layer_kustomizations" ]]; then
                local count
                count=$(echo "$layer_kustomizations" | wc -l | tr -d ' ')
                log_debug "Found ${layer} layer kustomizations: ${count}"
                while IFS= read -r ks; do
                    if [[ -n "$ks" ]]; then
                        log_debug "  Adding kustomization: $ks"
                        discovered_kustomizations+=("$ks")
                    fi
                done <<< "$layer_kustomizations"
            else
                log_debug "No kustomizations found with homelab.dev/layer=${layer}"
            fi
        done

        # Add any kustomizations without layer labels (for compatibility)
        log_debug "Discovering unlabeled kustomizations"
        local unlabeled_kustomizations
        unlabeled_kustomizations=$(kubectl get kustomizations -n flux-system \
            -o name 2>/dev/null | \
            sed 's|kustomization.kustomize.toolkit.fluxcd.io/||' | \
            while read -r ks_name; do
                # Check if this kustomization has the layer label
                if ! kubectl get kustomization "$ks_name" -n flux-system \
                    -o jsonpath='{.metadata.labels.homelab\.dev/layer}' 2>/dev/null | grep -q .; then
                    echo "$ks_name"
                fi
            done | sort)

        if [[ -n "$unlabeled_kustomizations" ]]; then
            local count
            count=$(echo "$unlabeled_kustomizations" | wc -l | tr -d ' ')
            log_debug "Found unlabeled kustomizations: ${count}"
            while IFS= read -r ks; do
                if [[ -n "$ks" ]]; then
                    log_debug "  Adding unlabeled kustomization: $ks"
                    discovered_kustomizations+=("$ks")
                fi
            done <<< "$unlabeled_kustomizations"
        fi

        if [[ ${#discovered_kustomizations[@]} -gt 0 ]]; then
            log_info "Auto-discovered ${#discovered_kustomizations[@]} kustomizations from cluster"
            # Output to stdout for capture by readarray
            printf '%s\n' "${discovered_kustomizations[@]}"
            return 0
        else
            log_warning "Auto-discovery found 0 kustomizations (labels may not be applied yet)"
            # Fall through to static fallback
        fi
    else
        log_warning "Cannot access cluster for auto-discovery"
        # Fall through to static fallback
    fi

    # Fallback to static list if auto-discovery fails or returns empty
    log_warning "Falling back to static kustomization list"
    local static_kustomizations=(
        "${INFRASTRUCTURE_KUSTOMIZATIONS[@]}"
        "${POLICY_KUSTOMIZATIONS[@]}"
        "${DATABASE_KUSTOMIZATIONS[@]}"
        "${APPLICATION_KUSTOMIZATIONS[@]}"
    )
    log_debug "Static fallback includes ${#static_kustomizations[@]} kustomizations"
    # Output static list to stdout
    printf '%s\n' "${static_kustomizations[@]}"
}

# Function to check if a kustomization is suspended
is_suspended() {
    local ks_name="$1"
    local suspend_status
    suspend_status=$(kubectl get kustomization "$ks_name" -n flux-system -o jsonpath='{.spec.suspend}' 2>/dev/null || echo "false")
    [[ "$suspend_status" == "true" ]]
}

# All kustomizations in dependency order
readarray -t ALL_KUSTOMIZATIONS < <(discover_kustomizations)

# Debug: Show what was actually captured
log_debug "Captured ${#ALL_KUSTOMIZATIONS[@]} kustomizations from discovery:"
for ks in "${ALL_KUSTOMIZATIONS[@]}"; do
    log_debug "  - $ks"
done

# Main reconciliation logic
main() {
    log_section "🚀 Starting Flux Reconciliation"

    # Step 0: Check for orphaned resources if requested
    if [[ "${CHECK_ORPHANS:-}" == "1" ]]; then
        check_orphaned_resources
        echo ""
    fi

    # Step 1: Always reconcile git source first to get latest changes
    log_section "📦 Step 1: Git Source Reconciliation"
    if ! reconcile_with_retry "source git" "homelab-k8s"; then
        log_error "Failed to reconcile git source, aborting"
        exit 1
    fi

    # Small delay to allow git source to propagate changes
    sleep 3

    # Determine which kustomizations to reconcile
    local kustomizations_to_reconcile=()

    if [ "$RECONCILE_ALL" = true ]; then
        log_info "No specific kustomizations provided, reconciling all in dependency order"
        kustomizations_to_reconcile=("${ALL_KUSTOMIZATIONS[@]}")

        # Additional safety check
        if [[ ${#kustomizations_to_reconcile[@]} -eq 0 ]]; then
            log_error "No kustomizations discovered! This should not happen."
            log_error "Check cluster connectivity and kustomization labels."
            exit 1
        fi
    else
        log_info "Reconciling specific kustomizations: ${SPECIFIC_KUSTOMIZATIONS[*]}"
        kustomizations_to_reconcile=("${SPECIFIC_KUSTOMIZATIONS[@]}")
    fi

    # Step 2: Reconcile kustomizations in dependency order
    log_section "🔧 Step 2: Kustomization Reconciliation"

    local failed_reconciliations=()
    local skipped_reconciliations=()

    log_info "Will attempt to reconcile ${#kustomizations_to_reconcile[@]} kustomizations:"
    for ks in "${kustomizations_to_reconcile[@]}"; do
        log_info "  - $ks"
    done
    echo ""

    for ks in "${kustomizations_to_reconcile[@]}"; do
        # Check if kustomization is suspended
        if is_suspended "$ks"; then
            log_warning "Skipping suspended kustomization: $ks"
            skipped_reconciliations+=("$ks")
            continue
        fi

        if ! reconcile_with_retry "kustomization" "$ks"; then
            failed_reconciliations+=("$ks")
        fi

        # Small delay to allow resources to settle
        sleep 2
    done

    # Report skipped reconciliations
    if [ ${#skipped_reconciliations[@]} -gt 0 ]; then
        log_section "⏸️  Skipped Reconciliations"
        for skipped in "${skipped_reconciliations[@]}"; do
            log_info "Skipped suspended: $skipped"
        done
    fi

    # Step 3: Health check and status report
    log_section "🏥 Step 3: Health Check and Status"

    echo "Kustomization Status:"
    flux get kustomizations -A

    echo -e "\\nHelmRelease Status:"
    flux get helmreleases -A

    # Report any failures
    if [ ${#failed_reconciliations[@]} -gt 0 ]; then
        log_section "❌ Reconciliation Failures"
        for failed in "${failed_reconciliations[@]}"; do
            log_error "Failed to reconcile: $failed"
        done

        log_warning "Some reconciliations failed. Check the status above and consider:"
        echo "  1. Checking resource dependencies"
        echo "  2. Verifying SOPS decryption is working"
        echo "  3. Ensuring required namespaces exist"
        echo "  4. Checking for resource conflicts"

        exit 1
    else
        log_section "🎉 Reconciliation Complete"
        log_success "All non-suspended kustomizations reconciled successfully!"

        # Final health summary
        echo -e "\\n📊 Health Summary:"
        local unhealthy_count=0
        for ks in "${kustomizations_to_reconcile[@]}"; do
            # Skip health check for suspended kustomizations
            if is_suspended "$ks"; then
                continue
            fi

            if ! check_kustomization_health "$ks"; then
                unhealthy_count=$((unhealthy_count + 1))
            fi
        done

        if [ $unhealthy_count -eq 0 ]; then
            log_success "All active kustomizations are healthy!"
        else
            log_warning "$unhealthy_count kustomization(s) are not in Ready state"
            echo "Run 'kubectl describe kustomization <name> -n flux-system' for details"
        fi
    fi
}

# Run main function
main
