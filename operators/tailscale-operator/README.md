# Tailscale Kubernetes Operator

This directory contains the GitOps configuration for the official Tailscale Kubernetes Operator. The operator enables exposing Kubernetes services privately to your Tailscale tailnet.

## Overview

The Tailscale operator:
- Exposes Kubernetes Services to your Tailscale network (not publicly)
- Creates Tailscale proxy pods that route traffic to your services
- Supports LoadBalancer services with `loadBalancerClass: tailscale`
- Can also expose Ingress resources via Tailscale

## Prerequisites

### 1. Create Tailscale OAuth Client

1. Go to [Tailscale Admin Console → Settings → OAuth clients](https://login.tailscale.com/admin/settings/oauth)
2. Click **Generate OAuth client**
3. Configure the client:
   - **Description**: `k8s-operator`
   - **Scopes**:
     - ✅ Devices: Core (Read & Write)
     - ✅ Auth Keys (Read & Write)
     - ✅ DNS (Read & Write) - optional, for MagicDNS
   - **Tags**: `tag:k8s-operator`
4. Copy the **Client ID** and **Client Secret**

### 2. Configure Tailscale ACLs

Add the following to your Tailscale ACL policy (admin console → Access Controls):

```json
{
  "tagOwners": {
    "tag:k8s-operator": ["autogroup:admin"],
    "tag:k8s": ["tag:k8s-operator"]
  },
  "acls": [
    {
      "action": "accept",
      "src": ["autogroup:member"],
      "dst": ["tag:k8s:*"]
    }
  ]
}
```

This allows:
- The operator to create and manage devices with `tag:k8s`
- All tailnet members to access services tagged with `tag:k8s`

### 3. Encrypt the OAuth Secret

After creating the OAuth client, encrypt the secret:

```bash
# Edit the secret file with your credentials
vim operators/tailscale-operator/base/operator-oauth-secret.sops.yaml

# Encrypt with SOPS
SOPS_AGE_KEY="AGE-SECRET-KEY-..." ./scripts/sops.sh encrypt \
  operators/tailscale-operator/base/operator-oauth-secret.sops.yaml
```

## Installation

The operator is deployed via ArgoCD. After encrypting the OAuth secret:

1. Commit and push the changes
2. ArgoCD will automatically sync the operator

## Validation Steps

### Check Operator Status

```bash
# Verify the operator pod is running
kubectl -n tailscale get pods

# Check operator logs
kubectl -n tailscale logs -l app.kubernetes.io/name=tailscale-operator

# Verify CRDs are installed
kubectl get crd | grep tailscale
```

Expected CRDs:
- connectors.tailscale.com
- dnsconfigs.tailscale.com
- proxyclasses.tailscale.com
- proxygroups.tailscale.com
- recorders.tailscale.com

### Test Service Exposure

Apply the test resources:

```bash
# Deploy the test whoami service
kubectl apply -k operators/tailscale-operator/test-resources/

# Wait for the Tailscale proxy to be ready
kubectl -n tailscale get pods -w

# Check the service has a Tailscale IP
kubectl -n tailscale get svc whoami-tailnet
```

The service should show a Tailscale IP (100.x.x.x range) in EXTERNAL-IP.

### Access the Service

From any device on your tailnet:

```bash
# Via Tailscale DNS (if MagicDNS enabled)
curl http://whoami-tailnet.<your-tailnet>.ts.net

# Or via Tailscale IP
curl http://100.x.x.x
```

### Cleanup Test Resources

```bash
kubectl delete -k operators/tailscale-operator/test-resources/
```

## Exposing Your Own Services

To expose a service to your tailnet:

```yaml
apiVersion: v1
kind: Service
metadata:
  name: my-service
  annotations:
    tailscale.com/expose: "true"
spec:
  type: LoadBalancer
  loadBalancerClass: tailscale
  selector:
    app: my-app
  ports:
    - port: 80
      targetPort: 8080
```

## Troubleshooting

### Operator Pod Not Starting
```bash
kubectl -n tailscale get events --sort-by='.lastTimestamp'
kubectl -n tailscale get secret operator-oauth
```

### Service Not Getting Tailscale IP
```bash
kubectl -n tailscale get pods -l tailscale.com/parent-resource=<service-name>
kubectl -n tailscale logs -l tailscale.com/parent-resource=<service-name>
```

## References

- [Tailscale Kubernetes Operator Docs](https://tailscale.com/kb/1236/kubernetes-operator)
- [Exposing Services](https://tailscale.com/kb/1439/kubernetes-operator-cluster-ingress)
- [OAuth Client Setup](https://tailscale.com/kb/1215/oauth-clients)
