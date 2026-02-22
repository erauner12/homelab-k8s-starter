.PHONY: help preflight static-validate static-validate-fast static-validate-full plan bootstrap talos-local-up talos-local-status talos-local-validate talos-local-down smoke-local smoke-cloud argocd-get-admin argocd-ui

help:
	@echo "Targets: preflight, static-validate, static-validate-fast, static-validate-full, plan, bootstrap, talos-local-up, talos-local-status, talos-local-validate, talos-local-down, smoke-local, smoke-cloud, argocd-get-admin, argocd-ui"

preflight:
	@./scripts/pre-bootstrap-test.sh

static-validate:
	@./scripts/static-validate.sh

static-validate-fast:
	@./scripts/static-validate-fast.sh

static-validate-full:
	@./scripts/static-validate-full.sh

plan:
	@./bin/homelabctl bootstrap plan

bootstrap:
	@./bin/homelabctl bootstrap run --kubeconfig ~/.kube/config

talos-local-up:
	@./scripts/talos/local-up.sh

talos-local-status:
	@./scripts/talos/local-status.sh

talos-local-validate:
	@./scripts/talos/local-validate.sh

talos-local-down:
	@./scripts/talos/local-down.sh

argocd-get-admin:
	@./scripts/argocd-get-admin.sh

argocd-ui:
	@./scripts/argocd-ui.sh

smoke-local:
	@./smoke/scripts/run.sh --profile local --context $${CLUSTER_NAME:-starter-talos}

smoke-cloud:
	@./smoke/scripts/run.sh --profile cloud
