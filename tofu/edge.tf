# edge — the homelab's reverse-proxy/ingress LXC.
#
# Tofu creates and sizes the container and attaches its NIC to the Proxmox
# bridge; the container's OS and addressing come from its NixOS flake config.

module "edge" {
  source = "./modules/lxc"

  vm_id        = var.edge_vm_id
  description  = "Homelab ingress (edge). Managed by OpenTofu; OS owned by hosts/ flake config."
  tags         = ["edge"]
  cores        = var.edge_cores
  memory       = var.edge_memory
  disk_size    = var.edge_disk_size
  unprivileged = false
  nesting      = false
  started      = false # TODO: flip to true once bootstrapped onto its flake config.

  proxmox_node_name   = var.proxmox_node_name
  container_datastore = var.container_datastore
  network_bridge      = var.network_bridge
  template_file_id    = var.template_file_id
}

moved {
  from = proxmox_virtual_environment_container.edge
  to   = module.edge.proxmox_virtual_environment_container.this
}
