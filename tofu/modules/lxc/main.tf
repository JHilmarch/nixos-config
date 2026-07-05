# Shared resource for a homelab NixOS LXC container.
#
# Every homelab host container shares the same proxmox_virtual_environment_
# container shape: same node, bridge, template, lifecycle semantics. This
# module encapsulates that shape — including the hard-won lifecycle.ignore_
# changes entries that prevent the HTTP 400/403 apply failures (NixOS owns
# OS/hostname after first boot; Proxmox rejects clearing a running
# container's hostname; features on a privileged container can only be
# changed by root@pam, not the API token).
#
# See hosts/cache/README-cache.md "Provisioning" for the ignore_changes
# rationale, and tofu/README.md for the overall provisioning flow.

resource "proxmox_virtual_environment_container" "this" {
  node_name   = var.proxmox_node_name
  vm_id       = var.vm_id
  description = var.description
  tags        = concat(["homelab"], var.tags)

  unprivileged = var.unprivileged

  # Only emit a features block when nesting is requested. A privileged
  # container (edge) has no features block at all and ignores features in
  # lifecycle; an unprivileged container (cache) sets nesting = true.
  dynamic "features" {
    for_each = var.nesting ? [1] : []
    content {
      nesting = true
    }
  }

  started       = var.started
  start_on_boot = true

  cpu {
    cores = var.cores
  }

  memory {
    dedicated = var.memory
    swap      = var.swap
  }

  disk {
    datastore_id = var.container_datastore
    size         = var.disk_size
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

  # NixOS owns the OS and hostname after first boot; Proxmox rejects clearing
  # a running container's hostname (HTTP 400). features is ignored because the
  # API token cannot manage it on privileged containers (HTTP 403); on
  # unprivileged containers nesting is set at create-time and does not drift.
  lifecycle {
    ignore_changes = [
      operating_system,
      initialization,
      features,
    ]
  }
}
