variable "cloudflare_api_token" {
  description = "Cloudflare API token with Zone DNS edit and Zero Trust Tunnel edit permissions"
  type        = string
  sensitive   = true
}

variable "cloudflare_account_id" {
  description = "Cloudflare account ID that owns the tunnel"
  type        = string
}

variable "zone" {
  description = "Authoritative DNS zone (example: maxhomelab.net)"
  type        = string
}

variable "tunnel_name" {
  description = "Name for the primary apps tunnel"
  type        = string
  default     = "apps-tunnel"
}

variable "origin_service" {
  description = "In-cluster service cloudflared should route all traffic to"
  type        = string
  default     = "https://envoy-public-tunnel.envoy-gateway-system.svc.cluster.local:443"
}
