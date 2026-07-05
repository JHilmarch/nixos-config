# cache — the homelab's LAN Nix binary cache LXC.
#
# Tofu creates and sizes the container and attaches its NIC to the Proxmox
# bridge; the container's OS and addressing come from its NixOS flake config
# (hosts/cache/, flake host nixos-cache). Larger disk than edge because it
# stores Nix store artifacts served to the LAN.
#
# The shared container shape lives in tofu/modules/lxc/. cache is unprivileged
# with nesting enabled so systemd boots; the API token manages the nesting
# feature on unprivileged containers.

module "cache" {
  source = "./modules/lxc"

  vm_id        = var.cache_vm_id
  description  = "Homelab LAN Nix binary cache. Managed by OpenTofu; OS owned by hosts/ flake config."
  tags         = ["cache"]
  cores        = var.cache_cores
  memory       = var.cache_memory
  swap         = var.cache_swap
  disk_size    = var.cache_disk_size
  unprivileged = true
  nesting      = true
  started      = true

  proxmox_node_name   = var.proxmox_node_name
  container_datastore = var.container_datastore
  network_bridge      = var.network_bridge
  template_file_id    = var.template_file_id
}

# Resource moved from the root module into module.cache. State follows the new
# address with no destroy/recreate cycle.
moved {
  from = proxmox_virtual_environment_container.cache
  to   = module.cache.proxmox_virtual_environment_container.this
}
