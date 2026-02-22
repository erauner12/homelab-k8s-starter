# Rackspace Spot Kubernetes Cluster

Terraform configuration for deploying a managed Kubernetes cluster on Rackspace Spot.

## Overview

This module provides a reusable pattern for low-cost homelab cloud clusters:
- managed Kubernetes control plane
- spot-priced worker nodes with bid configuration
- optional autoscaling
- kubeconfig output for bootstrap workflows

## Prerequisites

1. Rackspace Spot account
2. Spot API token
3. Terraform >= 1.0
4. SOPS + age (if using encrypted secrets file)

## Quick start

```bash
cd terraform/rackspace-spot

cp secrets.sops.yaml.example secrets.sops.yaml
cp terraform.tfvars.example terraform.tfvars

# Add token, then encrypt secrets file
SOPS_AGE_KEY="AGE-SECRET-KEY-..." sops -e -i secrets.sops.yaml

make init
make apply

# Use generated kubeconfig
eval "$(terraform output -raw kubectl_config_command)"

# Bootstrap ArgoCD app-of-apps from this repo
make bootstrap-cloud
```

## Configuration highlights

- `region`: Spot region
- `server_class`: worker node class
- `bid_price`: hourly bid per node
- `autoscaling_enabled`, `min_nodes`, `max_nodes`
- `kubernetes_version`

## Cost estimate

Use Terraform output:

```bash
terraform output estimated_monthly_cost
```

## Security notes

- Never commit decrypted secrets.
- Keep `secrets.sops.yaml` encrypted.
- Do not commit generated kubeconfig files.

## Outputs

- `cloudspace_name`
- `kubeconfig_path`
- `kubectl_config_command`
- `estimated_monthly_cost`
