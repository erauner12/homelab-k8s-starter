#!/bin/bash
set -e

echo "================================================"
echo "Creating ArgoCD Deploy Key"
echo "================================================"
echo ""

# Set key path
KEY_PATH="$HOME/.ssh/argocd-homelab-deploy-key"
KEY_NAME="argocd-homelab-deploy-key"

# Check if key already exists
if [ -f "$KEY_PATH" ]; then
    echo "[WARN] Deploy key already exists at $KEY_PATH"
    echo "Do you want to overwrite it? (y/n)"
    read -r response
    if [[ "$response" != "y" ]]; then
        echo "Using existing key..."
    else
        rm -f "$KEY_PATH" "$KEY_PATH.pub"
        ssh-keygen -t ed25519 -f "$KEY_PATH" -N "" -C "argocd@homelab-k8s"
        echo "[OK] New SSH key generated"
    fi
else
    ssh-keygen -t ed25519 -f "$KEY_PATH" -N "" -C "argocd@homelab-k8s"
    echo "[OK] SSH key generated"
fi

echo ""
echo "================================================"
echo "Public Key (add this to GitHub as deploy key):"
echo "================================================"
echo ""
cat "$KEY_PATH.pub"
echo ""

echo "================================================"
echo "GitHub Instructions:"
echo "================================================"
echo ""
echo "1. Go to: https://github.com/erauner/homelab-k8s/settings/keys/new"
echo "2. Title: ArgoCD Deploy Key (homelab-k8s)"
echo "3. Key: (paste the public key above)"
echo "4. [OK] Allow write access: NO (read-only is sufficient)"
echo "5. Click 'Add key'"
echo ""

echo "================================================"
echo "Kubernetes Secret Creation:"
echo "================================================"
echo ""

# Create the secret in Kubernetes
echo "Creating/updating Kubernetes secret..."
kubectl create secret generic argocd-ssh-key \
  --from-file=ssh-privatekey="$KEY_PATH" \
  --namespace=argocd \
  --dry-run=client -o yaml | kubectl apply -f -

echo "[OK] Kubernetes secret created/updated"
echo ""

echo "================================================"
echo "Update ArgoCD Repository Configuration:"
echo "================================================"
echo ""

# Create the repository secret manifest
cat > /tmp/argocd-repo-secret.yaml <<EOF
apiVersion: v1
kind: Secret
metadata:
  name: homelab-k8s-repo
  namespace: argocd
  labels:
    argocd.argoproj.io/secret-type: repository
type: Opaque
stringData:
  type: git
  url: git@github.com:erauner/homelab-k8s.git
  sshPrivateKey: |
$(sed 's/^/    /' "$KEY_PATH")
EOF

echo "Applying repository configuration..."
kubectl apply -f /tmp/argocd-repo-secret.yaml

echo "[OK] ArgoCD repository configured with new SSH key"
echo ""

echo "================================================"
echo "Verification:"
echo "================================================"
echo ""

echo "After adding the deploy key to GitHub, verify with:"
echo "kubectl exec -n argocd deployment/argocd-repo-server -- argocd-repo-server repo test git@github.com:erauner/homelab-k8s.git"
echo ""

echo "================================================"
echo "Cleanup Old Deploy Key (Optional):"
echo "================================================"
echo ""
echo "Once verified working, you can remove the old repository configuration:"
echo "kubectl delete secret repo-homelab-k8s -n argocd --ignore-not-found"
echo ""
echo "And optionally remove the previous deploy key from GitHub:"
echo "https://github.com/erauner/homelab-k8s/settings/keys"
echo ""
