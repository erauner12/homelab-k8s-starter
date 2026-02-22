provider "sops" {}

locals {
  resolved_spot_token = var.spot_token != null ? var.spot_token : data.sops_file.secrets[0].data["data.spot_token"]
}

provider "spot" {
  token = local.resolved_spot_token
}
