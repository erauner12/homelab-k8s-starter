output "apps_tunnel_id" {
  description = "Cloudflare tunnel ID used by the cloudflared-apps deployment"
  value       = cloudflare_zero_trust_tunnel_cloudflared.apps.id
}

output "apps_tunnel_token" {
  description = "Token for Kubernetes Secret cloudflared-apps-token (key: cf-tunnel-token)"
  value       = cloudflare_zero_trust_tunnel_cloudflared.apps.tunnel_token
  sensitive   = true
}

output "tunnel_cname_target" {
  description = "CNAME target that tunnel.<zone> points to"
  value       = cloudflare_record.tunnel.content
}
