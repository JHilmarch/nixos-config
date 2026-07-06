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

  dynamic "initialization" {
    for_each = var.ipv4_address != "" ? [1] : []
    content {
      ip_config {
        ipv4 {
          address = var.ipv4_address
          gateway = var.ipv4_gateway
        }
      }
    }
  }

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

# Bind mounts (var.mount_points) are applied here, not as a native mount_point
# block above: Proxmox restricts bind mounts to the root@pam user, so the API
# token the provider authenticates as cannot create them. Instead, SSH in as
# root@pam (the same id_ed25519_tofu key used by null_resource.zfs_keys_unlock
# in storage.tf) and run `pct set -mpN`. replace_triggered_by re-runs this
# whenever the container is (re)created, so a destroy/recreate cycle re-adds
# the mounts automatically — the underlying host paths (encrypted dataset
# subdirectories) survive recreate, so the keys persist.
resource "null_resource" "bind_mounts" {
  count = length(var.mount_points) > 0 ? 1 : 0

  lifecycle {
    replace_triggered_by = [proxmox_virtual_environment_container.this]
  }

  connection {
    type        = "ssh"
    user        = "root"
    host        = var.proxmox_ssh_host
    private_key = file(pathexpand(var.proxmox_ssh_private_key_path))
    timeout     = "2m"
  }

  provisioner "remote-exec" {
    inline = concat(
      [
        "ctid=${proxmox_virtual_environment_container.this.id}",
        # Idempotent guard: skip when the first declared mount is already
        # configured. Bind mounts added to a running container only activate
        # on next start, so stop + start bracket the pct set run.
        "pct config \"$ctid\" | grep -q 'mp=${var.mount_points[0].path}' || {",
        "  pct stop \"$ctid\"",
      ],
      [
        for i, mp in var.mount_points :
        "  pct set \"$ctid\" -mp${i} ${mp.volume},mp=${mp.path}"
      ],
      [
        "  pct start \"$ctid\"",
        "}",
      ]
    )
  }
}
