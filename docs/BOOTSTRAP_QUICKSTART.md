# Bootstrap Quickstart (ArgoCD)

```bash
./scripts/pre-bootstrap-test.sh
./bin/homelabctl bootstrap plan
./bin/homelabctl bootstrap run --kubeconfig ~/.kube/config
```

## Post-bootstrap checks
```bash
kubectl -n argocd get applications
kubectl get pods -n cert-manager
kubectl get pods -n external-secrets
kubectl get pods -n tailscale
```
