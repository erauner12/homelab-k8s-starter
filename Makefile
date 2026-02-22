.PHONY: help bootstrap plan preflight

help:
	@echo "Targets: preflight, plan, bootstrap"

preflight:
	@./scripts/pre-bootstrap-test.sh

plan:
	@./bin/homelabctl bootstrap plan

bootstrap:
	@./bin/homelabctl bootstrap run --kubeconfig ~/.kube/config
