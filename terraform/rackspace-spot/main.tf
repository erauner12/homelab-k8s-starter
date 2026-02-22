# Extract region suffix for server class (e.g., "iad" from "us-east-iad-1")
locals {
  region_suffix = split("-", var.region)[2]
}

# Rackspace Spot Cloudspace (Kubernetes cluster)
resource "spot_cloudspace" "this" {
  cloudspace_name    = var.cloudspace_name
  region             = var.region
  hacontrol_plane    = var.ha_control_plane
  kubernetes_version = var.kubernetes_version
  cni                = var.cni
  wait_until_ready   = var.wait_until_ready

  # Optional: Slack/Discord webhook for preemption warnings
  # preemption_webhook = var.preemption_webhook != "" ? var.preemption_webhook : null
}

# Worker node pool with spot pricing
resource "spot_spotnodepool" "workers" {
  cloudspace_name = spot_cloudspace.this.cloudspace_name
  server_class    = var.server_class
  bid_price       = var.bid_price

  # Autoscaling configuration (set to null to disable autoscaling)
  autoscaling = var.autoscaling_enabled ? {
    min_nodes = var.min_nodes
    max_nodes = var.max_nodes
  } : null

  # Fixed node count when autoscaling disabled
  desired_server_count = var.autoscaling_enabled ? null : var.desired_node_count

  # Node labels for workload scheduling
  labels = var.node_labels
}

# Save kubeconfig to local file for easy access
resource "local_file" "kubeconfig" {
  filename        = "${path.module}/kubeconfig-${var.cloudspace_name}.yaml"
  content         = data.spot_kubeconfig.cluster.raw
  file_permission = "0600"
}
