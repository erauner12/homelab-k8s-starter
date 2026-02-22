# Load SOPS-encrypted secrets by default.
# Set TF_VAR_spot_token to bypass this in CI.
data "sops_file" "secrets" {
  count = var.spot_token == null ? 1 : 0

  source_file = "secrets.sops.yaml"
}

# Retrieve kubeconfig after cluster is ready.
data "spot_kubeconfig" "cluster" {
  cloudspace_name = spot_cloudspace.this.cloudspace_name
}
