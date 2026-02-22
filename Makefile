# Makefile for homelab-k8s GitOps cluster management
# Run 'make help' for available commands

.DEFAULT_GOAL := help
.PHONY: help bootstrap smoke status rebuild clean validate validate-kustomize lint smoke-image test-helm test-helm-quick

# Colors for output
GREEN := \033[0;32m
YELLOW := \033[1;33m
RED := \033[0;31m
NC := \033[0m # No Color

help: ## Show this help message
	@echo "$(GREEN)homelab-k8s cluster management$(NC)"
	@echo ""
	@echo "$(YELLOW)Bootstrap commands:$(NC)"
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "  $(GREEN)%-12s$(NC) %s\n", $$1, $$2}'

bootstrap: ## Bootstrap the cluster from scratch
	@echo "$(GREEN)🚀 Bootstrapping homelab-k8s cluster...$(NC)"
	@./bin/homelabctl bootstrap run

smoke: ## Run smoke tests to verify cluster health
	@echo "$(GREEN)🔍 Running smoke tests...$(NC)"
	@./bin/homelabctl bootstrap smoke

status: ## Show Flux and cluster status
	@echo "$(GREEN)📊 Cluster Status$(NC)"
	@echo ""
	@echo "$(YELLOW)Flux Kustomizations (All Namespaces):$(NC)"
	@flux get ks -A
	@echo ""
	@echo "$(YELLOW)Flux Kustomizations (Detailed):$(NC)"
	@kubectl -n flux-system get kustomizations -o wide
	@echo ""
	@echo "$(YELLOW)GitRepository Status:$(NC)"
	@flux get sources git
	@echo ""
	@echo "$(YELLOW)Failed Pods:$(NC)"
	@kubectl get pods -A | grep -v Running | grep -v Completed || echo "  All pods are healthy! ✅"

rebuild: ## Completely rebuild the cluster (DESTRUCTIVE)
	@echo "$(RED)⚠️  This will completely destroy and rebuild the cluster!$(NC)"
	@echo "$(RED)Press Ctrl+C to abort, or Enter to continue...$(NC)"
	@read
	@echo "$(YELLOW)Destroying cluster...$(NC)"
	@# Add your cluster destruction command here (e.g., Talos reset)
	@# talosctl reset --nodes <node-ips> --graceful=false --reboot
	@echo "$(RED)Please manually destroy your cluster and recreate it$(NC)"
	@echo "$(YELLOW)Then run 'make bootstrap' to rebuild$(NC)"

clean: ## Clean up failed resources and restart Flux reconciliation
	@echo "$(GREEN)🧹 Cleaning up cluster resources...$(NC)"
	@echo "Restarting Flux reconciliation..."
	@flux reconcile source git homelab-k8s --with-source
	@flux reconcile kustomization home-root --with-source

validate: ## Validate cluster configuration
	@echo "$(GREEN)✅ Validating cluster configuration...$(NC)"
	@./scripts/validate-gitops-split.sh
	@echo "Checking for Helm conflicts..."
	@./scripts/check-helmrelease-conflicts.sh

# Kustomize build options - MUST match ArgoCD's kustomize.buildOptions
# Source: infrastructure/argocd/base/values/values.yaml
KUSTOMIZE_BUILD_OPTS := --load-restrictor=LoadRestrictionsNone --enable-helm --enable-alpha-plugins --enable-exec

validate-kustomize: ## Validate all kustomize builds (matches ArgoCD/CI settings)
	@echo "$(GREEN)🔨 Validating kustomize builds...$(NC)"
	@echo "Using flags: $(KUSTOMIZE_BUILD_OPTS)"
	@echo ""
	@FAILED=0; \
	DIRS=$$(find \
		apps/*/base \
		apps/*/overlays/* \
		apps/*/stack/* \
		apps/*/db/base \
		apps/*/db/overlays/* \
		infrastructure/base/* \
		infrastructure/*/base \
		infrastructure/*/overlays/* \
		security/*/base \
		security/*/overlays/* \
		-name kustomization.yaml -type f 2>/dev/null | xargs -I{} dirname {} | sort -u); \
	TOTAL=$$(echo "$$DIRS" | wc -l | tr -d ' '); \
	echo "Found $$TOTAL directories to validate"; \
	echo ""; \
	for dir in $$DIRS; do \
		if kustomize build $(KUSTOMIZE_BUILD_OPTS) "$$dir" > /dev/null 2>&1; then \
			echo "  ✓ $$dir"; \
		else \
			echo "  $(RED)✗ $$dir$(NC)"; \
			kustomize build $(KUSTOMIZE_BUILD_OPTS) "$$dir" 2>&1 | tail -5; \
			FAILED=1; \
		fi; \
	done; \
	echo ""; \
	if [ $$FAILED -eq 1 ]; then \
		echo "$(RED)Some builds failed!$(NC)"; \
		exit 1; \
	else \
		echo "$(GREEN)All builds passed!$(NC)"; \
	fi

lint: ## Lint YAML files and run pre-commit checks
	@echo "$(GREEN)🔍 Running linting checks...$(NC)"
	@if command -v pre-commit >/dev/null 2>&1; then \
		pre-commit run --all-files; \
	else \
		echo "$(YELLOW)pre-commit not installed - skipping lint checks$(NC)"; \
	fi

test-helm: ## Run Helm chart determinism tests (full - tests all charts)
	@echo "$(GREEN)🎯 Running Helm determinism tests...$(NC)"
	@echo "This tests that all Helm charts render identically across multiple runs."
	@echo "Non-deterministic charts cause ArgoCD sync loops."
	@echo ""
	go test -v -timeout 10m ./test/helm/...

test-helm-quick: ## Run Helm discovery validation only (fast - no chart downloads)
	@echo "$(GREEN)🔍 Running Helm discovery validation...$(NC)"
	go test -v -run TestDiscovery ./test/helm/...

# Smoke test container image
SMOKE_IMAGE := docker.nexus.erauner.dev/homelab/smoke
SMOKE_TAG := $(shell git describe --tags --always --dirty 2>/dev/null || echo "dev")

smoke-image: ## Build and push the smoke test container image
	@echo "$(GREEN)🐳 Building smoke test image...$(NC)"
	@echo "Image: $(SMOKE_IMAGE):$(SMOKE_TAG)"
	docker build \
		--build-arg VERSION=$(SMOKE_TAG) \
		--build-arg COMMIT=$(shell git rev-parse --short HEAD) \
		--build-arg BUILD_DATE=$(shell date -u +%Y-%m-%dT%H:%M:%SZ) \
		-t $(SMOKE_IMAGE):$(SMOKE_TAG) \
		-t $(SMOKE_IMAGE):latest \
		-f tools/smoke/Dockerfile .
	@echo "$(GREEN)📤 Pushing to Nexus...$(NC)"
	docker push $(SMOKE_IMAGE):$(SMOKE_TAG)
	docker push $(SMOKE_IMAGE):latest
	@echo "$(GREEN)✅ Done! Image: $(SMOKE_IMAGE):$(SMOKE_TAG)$(NC)"

# ArgoCD specific commands
argocd-password: ## Get ArgoCD admin password
	@echo "$(GREEN)🔑 ArgoCD Admin Password:$(NC)"
	@kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d
	@echo ""

argocd-ui: ## Open ArgoCD UI (requires open command)
	@echo "$(GREEN)🌐 Opening ArgoCD UI...$(NC)"
	@echo "URL: https://argocd.erauner.dev"
	@if command -v open >/dev/null 2>&1; then \
		open https://argocd.erauner.dev; \
	else \
		echo "Navigate to: https://argocd.erauner.dev"; \
	fi

# Debugging commands
debug-flux: ## Debug Flux issues
	@echo "$(GREEN)🐛 Debugging Flux...$(NC)"
	@echo ""
	@echo "$(YELLOW)Flux System Pods:$(NC)"
	@kubectl -n flux-system get pods
	@echo ""
	@echo "$(YELLOW)Recent Events:$(NC)"
	@kubectl -n flux-system get events --sort-by='.lastTimestamp' | tail -10

debug-argocd: ## Debug ArgoCD issues
	@echo "$(GREEN)🐛 Debugging ArgoCD...$(NC)"
	@echo ""
	@echo "$(YELLOW)ArgoCD Pods:$(NC)"
	@kubectl -n argocd get pods
	@echo ""
	@echo "$(YELLOW)ArgoCD Applications:$(NC)"
	@kubectl -n argocd get applications

logs-flux: ## Show Flux controller logs
	@echo "$(GREEN)📋 Flux Controller Logs:$(NC)"
	@kubectl -n flux-system logs -l app=kustomize-controller --tail=50

logs-argocd: ## Show ArgoCD server logs
	@echo "$(GREEN)📋 ArgoCD Server Logs:$(NC)"
	@kubectl -n argocd logs -l app.kubernetes.io/name=argocd-server --tail=50

# Emergency commands
emergency-suspend: ## Suspend all Flux reconciliation (EMERGENCY)
	@echo "$(RED)🚨 EMERGENCY: Suspending all Flux reconciliation$(NC)"
	@flux suspend kustomization --all
	@echo "$(YELLOW)To resume: make emergency-resume$(NC)"

emergency-resume: ## Resume all Flux reconciliation
	@echo "$(GREEN)▶️  Resuming all Flux reconciliation$(NC)"
	@flux resume kustomization --all

# Development commands
dev-sync: ## Force sync all GitOps resources
	@echo "$(GREEN)🔄 Force syncing all resources...$(NC)"
	@flux reconcile source git homelab-k8s --with-source
	@flux reconcile kustomization --all

dev-reset-argocd: ## Reset ArgoCD admin password
	@echo "$(GREEN)🔄 Resetting ArgoCD admin password...$(NC)"
	@kubectl -n argocd delete secret argocd-initial-admin-secret
	@kubectl -n argocd rollout restart deployment argocd-server
	@echo "$(YELLOW)New password will be available in ~1 minute$(NC)"

argocd-refresh: ## Force refresh ArgoCD parent app and optionally sync a child (usage: make argocd-refresh [APP=appname])
	@echo "$(GREEN)🔄 Refreshing ArgoCD app-of-apps...$(NC)"
	@bash hack/argocd-refresh.sh $(APP)

# Stage-specific commands
bootstrap-stage: ## Bootstrap a specific stage (usage: make bootstrap-stage STAGE=crds)
	@if [ -z "$(STAGE)" ]; then \
		echo "$(RED)Error: STAGE variable required$(NC)"; \
		echo "Usage: make bootstrap-stage STAGE=<stage>"; \
		echo "Stages: crds, secrets, namespaces, infra-core, operators, argocd"; \
		exit 1; \
	fi
	@echo "$(GREEN)🎯 Bootstrapping stage: $(STAGE)$(NC)"
	@./bin/homelabctl bootstrap stage --stage $(STAGE)
