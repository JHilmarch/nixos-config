# cache — the homelab's LAN Nix binary cache LXC.
#
# Tofu creates and sizes the container and attaches its NIC to the Proxmox
# bridge; the container's OS and addressing come from its NixOS flake config
# (hosts/cache/, flake host nixos-cache). Larger disk than edge because it
# stores Nix store artifacts served to the LAN.

resource "proxmox_virtual_environment_container" "cache" {
  node_name   = var.proxmox_node_name
  vm_id       = var.cache_vm_id
  description = "Homelab LAN Nix binary cache. Managed by OpenTofu; OS owned by hosts/ flake config."
  tags        = ["homelab", "cache"]

  # Unprivileged + nesting so systemd boots and the token can set nesting.
  unprivileged = true

  features {
    nesting = true
  }

  started       = true
  start_on_boot = true

  cpu {
    cores = var.cache_cores
  }

  memory {
    dedicated = var.cache_memory
    swap      = var.cache_swap
  }

  disk {
    datastore_id = var.container_datastore
    size         = var.cache_disk_size
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

  # NixOS owns the OS and hostname; see hosts/cache/README-cache.md.
  lifecycle {
    ignore_changes = [
      operating_system,
      initialization,
    ]
  }
}
