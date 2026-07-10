# forge — the homelab's git forge LXC.
#
# Tofu creates and sizes the container and attaches its NIC to the Proxmox
# bridge; the container's OS and addressing come from its NixOS flake config.
# Bare base host today (no workload); Forgejo + Postgres land in T2.

module "forge" {
  source = "./modules/lxc"

  vm_id        = var.forge_vm_id
  hostname     = "homelab-forge"
  description  = "Homelab git forge (forge). Managed by OpenTofu; OS owned by hosts/ flake config."
  tags         = ["forge"]
  cores        = var.forge_cores
  memory       = var.forge_memory
  disk_size    = var.forge_disk_size
  unprivileged = true
  nesting      = true
  started      = true

  proxmox_node_name   = var.proxmox_node_name
  container_datastore = var.container_datastore
  network_bridge      = var.network_bridge
  template_file_id    = var.template_file_id

  ipv4_address = "192.168.2.109/24"
  ipv4_gateway = "192.168.2.1"

  proxmox_ssh_host             = var.proxmox_ssh_host
  proxmox_ssh_private_key_path = var.proxmox_ssh_private_key_path
}
