# Cloudflare Tunnel Terraform (Minimal)

This module creates the minimum Cloudflare resources needed for starter ingress via cloudflared:
- one Zero Trust tunnel (`apps-tunnel` by default)
- tunnel config with catch-all route to Envoy in-cluster service
- `tunnel.<zone>` CNAME used by External-DNS annotation targets

## Prerequisites
- Cloudflare zone already exists (for example a Porkbun domain delegated to Cloudflare nameservers)
- Cloudflare API token with DNS and Zero Trust tunnel permissions
- `terraform` installed

## Usage
1. Export credentials:
```bash
export TF_VAR_cloudflare_api_token="..."
```
2. Set inputs in `terraform.tfvars` (copy from example):
```bash
cp terraform.tfvars.example terraform.tfvars
```
3. Apply:
```bash
terraform init
terraform apply
```
4. Create Kubernetes secret for cloudflared:
```bash
kubectl -n network create secret generic cloudflared-apps-token \
  --from-literal=cf-tunnel-token="$(terraform output -raw apps_tunnel_token)" \
  --dry-run=client -o yaml | kubectl apply -f -
```

## Notes
- Keep `terraform.tfstate` private; it contains sensitive tunnel data.
- The starter repo expects `cf-tunnel-token` key in secret `cloudflared-apps-token`.
