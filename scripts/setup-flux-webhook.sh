#!/usr/bin/env bash
set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

REPO="erauner/homelab-k8s"
WEBHOOK_URL="https://flux-webhook.erauner.dev/hook"

echo "🔧 Setting up Flux webhook for GitHub repository..."

# Check for gh CLI
if ! command -v gh &> /dev/null; then
    echo -e "${RED}❌ gh CLI not found. Please install GitHub CLI.${NC}"
    exit 1
fi

# Check authentication
if ! gh auth status &> /dev/null; then
    echo -e "${RED}❌ Not authenticated with GitHub. Run 'gh auth login' first.${NC}"
    exit 1
fi

# Wait for the webhook receiver to be ready
echo "⏳ Waiting for Flux webhook receiver to be ready..."
kubectl wait --for=condition=ready receiver/github-homelab -n flux-system --timeout=300s

# Get the webhook secret from Kubernetes
echo "🔑 Retrieving webhook secret from cluster..."
WEBHOOK_SECRET=$(kubectl get secret flux-webhook-secret -n flux-system -o jsonpath='{.data.token}' | base64 -d)

if [ -z "$WEBHOOK_SECRET" ]; then
    echo -e "${RED}❌ Failed to retrieve webhook secret from cluster${NC}"
    echo "Make sure the ExternalSecret has been synced and the secret exists"
    exit 1
fi

# Check if webhook already exists
echo "🔍 Checking for existing webhooks..."
EXISTING_WEBHOOK=$(gh api repos/$REPO/hooks --jq ".[] | select(.config.url == \"$WEBHOOK_URL\") | .id" || true)

if [ -n "$EXISTING_WEBHOOK" ]; then
    echo -e "${YELLOW}⚠️  Webhook already exists (ID: $EXISTING_WEBHOOK). Updating configuration...${NC}"

    # Update existing webhook
    gh api repos/$REPO/hooks/$EXISTING_WEBHOOK \
        --method PATCH \
        -f config[url]="$WEBHOOK_URL" \
        -f config[content_type]="json" \
        -f config[secret]="$WEBHOOK_SECRET" \
        -f config[insecure_ssl]="0" \
        -f active=true \
        -f events[]="push" \
        -f events[]="ping"

    echo -e "${GREEN}✅ Updated existing webhook${NC}"
else
    echo "📝 Creating new webhook..."

    # Create new webhook
    gh api repos/$REPO/hooks \
        --method POST \
        -f name="web" \
        -f config[url]="$WEBHOOK_URL" \
        -f config[content_type]="json" \
        -f config[secret]="$WEBHOOK_SECRET" \
        -f config[insecure_ssl]="0" \
        -f active=true \
        -f events[]="push" \
        -f events[]="ping"

    echo -e "${GREEN}✅ Created new webhook${NC}"
fi

# Test the webhook with a ping
echo "🏓 Testing webhook with ping event..."
WEBHOOK_ID=$(gh api repos/$REPO/hooks --jq ".[] | select(.config.url == \"$WEBHOOK_URL\") | .id")

if gh api repos/$REPO/hooks/$WEBHOOK_ID/pings --method POST; then
    echo -e "${GREEN}✅ Webhook ping successful!${NC}"
else
    echo -e "${YELLOW}⚠️  Webhook ping failed. Check the logs:${NC}"
    echo "  kubectl logs -n flux-system deployment/webhook-receiver"
fi

echo ""
echo "📊 Webhook configuration complete!"
echo "   URL: $WEBHOOK_URL"
echo "   Events: push, ping"
echo ""
echo "Next steps:"
echo "1. Push a change to the repository to test the webhook"
echo "2. Monitor Flux logs: kubectl logs -n flux-system deployment/source-controller -f"
echo "3. Check webhook deliveries: https://github.com/$REPO/settings/hooks"
