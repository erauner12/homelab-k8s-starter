.PHONY: check-env init plan apply apply-auto destroy fmt validate output kubeconfig bootstrap-cloud

check-env:
	@if [ -n "$$TF_VAR_spot_token" ]; then \
		echo "Using TF_VAR_spot_token override"; \
	elif [ -f "secrets.sops.yaml" ]; then \
		test -n "$$SOPS_AGE_KEY" -o -n "$$SOPS_AGE_KEY_FILE" || (echo "ERROR: set SOPS_AGE_KEY or SOPS_AGE_KEY_FILE to decrypt secrets.sops.yaml" && exit 1); \
		echo "Using secrets.sops.yaml + SOPS"; \
	else \
		echo "ERROR: provide TF_VAR_spot_token or create secrets.sops.yaml"; \
		exit 1; \
	fi

init: check-env
	terraform init

plan: check-env
	terraform plan -out=tfplan

apply: plan
	terraform apply tfplan

apply-auto: check-env
	terraform apply -auto-approve

destroy: check-env
	terraform destroy

fmt:
	terraform fmt -recursive

validate:
	terraform validate

output:
	terraform output

kubeconfig:
	@echo "Kubeconfig saved to: $$(terraform output -raw kubeconfig_path)"
	@echo "Run: $$(terraform output -raw kubectl_config_command)"

bootstrap-cloud:
	KUBECONFIG=$$(terraform output -raw kubeconfig_path) kubectl apply -k ../../clusters/cloud/bootstrap

cost:
	@terraform output estimated_monthly_cost
