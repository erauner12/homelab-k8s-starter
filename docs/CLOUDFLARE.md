# Cloudflare Tunnel (Optional)

Use this if you want public DNS/domain access instead of only Tailscale access.

## What gets deployed
- `cloudflared-apps` in namespace `network`
- Cloudflare tunnel token secret `cloudflared-apps-token`
- Existing External-DNS records target `tunnel.<your-zone>`

## 1. Create Cloudflare resources (Terraform)
From `terraform/cloudflare`:
```bash
cd terraform/cloudflare
export TF_VAR_cloudflare_api_token="..."
cp terraform.tfvars.example terraform.tfvars
# edit zone + cloudflare_account_id
terraform init
terraform apply
```

## 2. Create Kubernetes tunnel token secret
```bash
kubectl -n network create secret generic cloudflared-apps-token \
  --from-literal=cf-tunnel-token="$(cd terraform/cloudflare && terraform output -raw apps_tunnel_token)" \
  --dry-run=client -o yaml | kubectl apply -f -
```

## 3. Ensure cloudflared app is present in ArgoCD
The app manifest is part of the default cloud operators set:
- `clusters/cloud/argocd/operators/cloudflared-apps-app.yaml`

To re-apply if needed:
```bash
kubectl apply -k clusters/cloud/argocd/operators
```

## 4. Verify
```bash
kubectl -n argocd get application cloudflared-apps
kubectl -n network get pods -l app.kubernetes.io/name=cloudflared
```

## Domain note
Starter defaults still use `erauner.cloud` in several host annotations. Update those hostnames and `domainFilters` for your cousin's zone before production use.
