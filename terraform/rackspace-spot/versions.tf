terraform {
  required_version = ">= 1.0"

  required_providers {
    spot = {
      source  = "rackerlabs/spot"
      version = ">= 0.1"
    }
    sops = {
      source  = "carlpett/sops"
      version = ">= 1.0"
    }
    local = {
      source  = "hashicorp/local"
      version = ">= 2.0"
    }
  }

  backend "local" {
    path = "terraform.tfstate"
  }
}
