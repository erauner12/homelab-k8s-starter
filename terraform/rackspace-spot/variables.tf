variable "spot_token" {
  description = "Rackspace Spot API token override (optional). If null, read from secrets.sops.yaml."
  type        = string
  default     = null
  sensitive   = true
}

variable "cloudspace_name" {
  description = "Name for the Spot cloudspace (cluster)"
  type        = string
  default     = "starter-cloud"
}

variable "region" {
  description = "Rackspace Spot region (e.g., us-east-iad-1, us-central-dfw-1)"
  type        = string
  default     = "us-east-iad-1"
}

variable "kubernetes_version" {
  description = "Kubernetes version (e.g., 1.31.1)"
  type        = string
  default     = "1.31.1"
}

variable "ha_control_plane" {
  description = "Enable high-availability control plane (costs more)"
  type        = bool
  default     = false
}

variable "cni" {
  description = "Container Network Interface (calico or cilium if available)"
  type        = string
  default     = "calico"
}

variable "wait_until_ready" {
  description = "Wait for cluster to be ready before completing"
  type        = bool
  default     = true
}

# Node pool configuration
variable "node_pool_name" {
  description = "Name for the worker node pool"
  type        = string
  default     = "workers"
}

variable "server_class" {
  description = "Server class for worker nodes (e.g., gp.vs1.small-iad, gp.vs1.medium-iad, gp.vs1.large-iad)"
  type        = string
  default     = "gp.vs1.large-iad"
}

variable "bid_price" {
  description = "Bid price per node per hour (in USD). Higher = more likely to get/keep nodes."
  type        = number
  default     = 0.01
}

variable "autoscaling_enabled" {
  description = "Enable autoscaling for the node pool"
  type        = bool
  default     = true
}

variable "min_nodes" {
  description = "Minimum number of nodes (when autoscaling enabled)"
  type        = number
  default     = 2
}

variable "max_nodes" {
  description = "Maximum number of nodes (when autoscaling enabled)"
  type        = number
  default     = 4
}

variable "desired_node_count" {
  description = "Desired node count (when autoscaling disabled)"
  type        = number
  default     = 2
}

variable "node_labels" {
  description = "Kubernetes labels to apply to nodes"
  type        = map(string)
  default = {
    "node-type" = "spot-worker"
  }
}

variable "preemption_webhook" {
  description = "Webhook URL for preemption notifications (e.g., Slack webhook)"
  type        = string
  default     = ""
}

variable "tags" {
  description = "Tags for the cloudspace"
  type        = list(string)
  default     = ["homelab", "cloud", "spot"]
}
