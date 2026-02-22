.PHONY: help preflight static-validate static-validate-fast static-validate-full plan bootstrap kind-up kind-status kind-validate kind-down

help:
	@echo "Targets: preflight, static-validate, static-validate-fast, static-validate-full, plan, bootstrap, kind-up, kind-status, kind-validate, kind-down"

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
