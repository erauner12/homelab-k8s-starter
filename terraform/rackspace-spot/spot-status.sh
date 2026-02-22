#!/bin/bash
# Quick status check for Rackspace Spot cluster using Terraform
# Usage: ./spot-status.sh [--refresh]

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

echo "=== Rackspace Spot Cluster Status ==="
echo ""

# Check if terraform state exists
if ! terraform state list &>/dev/null; then
    echo "No Terraform state found. Run 'terraform apply' first."
    exit 1
fi

# Optionally refresh state
if [ "${1:-}" == "--refresh" ]; then
    echo "Refreshing Terraform state..."
    terraform apply -refresh-only -auto-approve | grep -E "^(spot_|Apply complete)" || true
    echo ""
fi

# Get cluster info from state
echo "Cloudspace: $(terraform output -raw cloudspace_name 2>/dev/null || echo 'unknown')"
echo "Region: $(terraform output -raw cloudspace_region 2>/dev/null || echo 'unknown')"
echo "K8s Version: $(terraform output -raw kubernetes_version 2>/dev/null || echo 'unknown')"
echo "Estimated Cost: $(terraform output -raw estimated_monthly_cost 2>/dev/null || echo 'unknown')"
echo ""

KUBECONFIG_PATH="$(terraform output -raw kubeconfig_path 2>/dev/null || true)"

if [ -n "$KUBECONFIG_PATH" ] && [ -f "$KUBECONFIG_PATH" ]; then
    echo "=== Cluster Connectivity ==="
    if KUBECONFIG="$KUBECONFIG_PATH" kubectl cluster-info &>/dev/null; then
        echo "[OK] Cluster is reachable"
        echo ""
        echo "=== Nodes ==="
        KUBECONFIG="$KUBECONFIG_PATH" kubectl get nodes -o wide 2>/dev/null || echo "Failed to get nodes"
        echo ""
        echo "=== ArgoCD Applications ==="
        KUBECONFIG="$KUBECONFIG_PATH" kubectl get applications -n argocd --no-headers 2>/dev/null | \
            awk '{printf "%-35s %-12s %s\n", $1, $2, $3}' || echo "ArgoCD not installed"
    else
        echo "[ERR] Cluster is not reachable"
        echo "Try: ./spot-status.sh --refresh"
    fi
else
    echo "Kubeconfig file not found from terraform output."
    echo "Run 'terraform apply' to generate it."
fi
