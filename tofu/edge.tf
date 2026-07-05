# edge — the homelab's reverse-proxy/ingress LXC.
#
# Tofu creates and sizes the container and attaches its NIC to the Proxmox
# bridge; the container's OS and addressing come from its NixOS flake config.

resource "proxmox_virtual_environment_container" "edge" {
  node_name   = var.proxmox_node_name
  vm_id       = var.edge_vm_id
  description = "Homelab ingress (edge). Managed by OpenTofu; OS owned by hosts/ flake config."
  tags        = ["homelab", "edge"]

  # Match templates/proxmox-lxc.nix (privileged = true).
  unprivileged = false

  # TODO: flip to true once the container is bootstrapped onto its flake config.
  # Do not auto-start on apply; it is converged via the bootstrap first.
  started       = false
  start_on_boot = true

  cpu {
    cores = var.edge_cores
  }

  memory {
    dedicated = var.edge_memory
  }

  disk {
    datastore_id = var.container_datastore
    size         = var.edge_disk_size
  }

  # NIC on the bridge only — no static IP here (owned by the NixOS config).
  network_interface {
    name   = "eth0"
    bridge = var.network_bridge
  }

  operating_system {
    template_file_id = var.template_file_id
    type             = "nixos"
  }

  # NixOS owns the OS/hostname; features stay operator-managed on this
  # privileged container. See hosts/cache/README-cache.md.
  lifecycle {
    ignore_changes = [
      operating_system,
      initialization,
      features,
    ]
  }
}
