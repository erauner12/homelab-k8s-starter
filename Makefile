.PHONY: help preflight plan bootstrap kind-up kind-status kind-validate kind-down

help:
	@echo "Targets: preflight, plan, bootstrap, kind-up, kind-status, kind-validate, kind-down"

preflight:
	@./scripts/pre-bootstrap-test.sh

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
