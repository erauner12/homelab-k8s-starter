data "cloudflare_zone" "primary" {
  name = var.zone
}

resource "random_password" "apps_tunnel_secret" {
  length = 32
}

resource "cloudflare_zero_trust_tunnel_cloudflared" "apps" {
  account_id = var.cloudflare_account_id
  name       = var.tunnel_name
  secret     = base64encode(random_password.apps_tunnel_secret.result)
}

resource "cloudflare_zero_trust_tunnel_cloudflared_config" "apps" {
  account_id = var.cloudflare_account_id
  tunnel_id  = cloudflare_zero_trust_tunnel_cloudflared.apps.id

  config {
    ingress_rule {
      service = var.origin_service
      origin_request {
        no_tls_verify = true
        http2_origin  = true
      }
    }

    ingress_rule {
      service = "http_status:404"
    }
  }
}

resource "cloudflare_record" "tunnel" {
  zone_id = data.cloudflare_zone.primary.id
  name    = "tunnel"
  content = "${cloudflare_zero_trust_tunnel_cloudflared.apps.id}.cfargotunnel.com"
  type    = "CNAME"
  ttl     = 1
  proxied = true
  comment = "External-DNS target for homelab services via apps tunnel"
}
