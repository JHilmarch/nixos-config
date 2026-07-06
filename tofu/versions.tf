terraform {
  required_version = ">= 1.6.0"

  required_providers {
    proxmox = {
      source  = "bpg/proxmox"
      version = "~> 0.111"
    }
    null = {
      source  = "hashicorp/null"
      version = "~> 3.2"
    }
  }
}
