.PHONY: help preflight static-validate static-validate-fast static-validate-full plan bootstrap kind-up kind-status kind-validate kind-down talos-local-up talos-local-status talos-local-down

help:
	@echo "Targets: preflight, static-validate, static-validate-fast, static-validate-full, plan, bootstrap, kind-up, kind-status, kind-validate, kind-down, talos-local-up, talos-local-status, talos-local-down"

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

kind-up:
	@./scripts/kind-up.sh

kind-status:
	@./scripts/kind-status.sh

kind-validate:
	@./scripts/kind-validate.sh

kind-down:
	@./scripts/kind-down.sh

talos-local-up:
	@./scripts/talos/local-up.sh

talos-local-status:
	@./scripts/talos/local-status.sh

talos-local-down:
	@./scripts/talos/local-down.sh
