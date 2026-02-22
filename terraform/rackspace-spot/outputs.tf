output "cloudspace_name" {
  description = "Spot cloudspace (cluster) name"
  value       = spot_cloudspace.this.cloudspace_name
}

output "cloudspace_region" {
  description = "Spot cloudspace region"
  value       = spot_cloudspace.this.region
}

output "kubernetes_version" {
  description = "Kubernetes version"
  value       = spot_cloudspace.this.kubernetes_version
}

output "kubeconfig_path" {
  description = "Path to the generated kubeconfig file"
  value       = local_file.kubeconfig.filename
}

output "kubeconfig_raw" {
  description = "Raw kubeconfig for this cluster"
  value       = data.spot_kubeconfig.cluster.raw
  sensitive   = true
}

output "kubectl_config_command" {
  description = "Command to use the kubeconfig"
  value       = "export KUBECONFIG=${abspath(local_file.kubeconfig.filename)}"
}

output "node_pool_server_class" {
  description = "Server class used for worker nodes"
  value       = spot_spotnodepool.workers.server_class
}

output "node_pool_bid_price" {
  description = "Current bid price per node per hour"
  value       = spot_spotnodepool.workers.bid_price
}

output "estimated_monthly_cost" {
  description = "Estimated monthly cost (bid_price * nodes * 730 hours)"
  value       = format("$%.2f/mo (at %d nodes)", var.bid_price * var.min_nodes * 730, var.min_nodes)
}
