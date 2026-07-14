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
# The Proxmox CT hostname (var.hostname → initialization.hostname, e.g.
# "homelab-edge") is what the Proxmox UI and `pct list` display; it is set at
# create time only. Because initialization is in lifecycle.ignore_changes,
# renaming an already-running container is a one-time `pct set <ctid>
# --hostname <name>` or a destroy/recreate (see tofu/README.md). NixOS still
# owns the in-container hostname via networking.hostName from the first switch.
#
# A mount is chowned host-side only when its entry sets `owner` ("uid:gid" in the
# Proxmox host namespace). On an unprivileged LXC host-root (uid 0) is not mapped
# into the guest, so a fresh host-root-owned dataset is squashed to nobody (65534)
# inside the container and the in-container service cannot chown it itself. The
# owner is therefore the subuid base (100000) plus the in-container uid/gid:
# /persist uses "100000:100000" (container-root, so sshd/sops-nix can read the
# host key — otherwise sshd crash-loops and secret decryption fails on first
# boot); the forge repo dataset uses "100996:100995" (forgejo). Mounts with no
# `owner` keep their host ownership — correct for the NFS-backed NAS mount, whose
# ownership is fixed on the NAS side and must not be chowned to a subuid.
#
# See hosts/cache/README-cache.md "Provisioning" for the ignore_changes
# rationale, and tofu/README.md for the overall provisioning flow.

resource "proxmox_virtual_environment_container" "this" {
  node_name   = var.proxmox_node_name
  vm_id       = var.vm_id
  description = var.description
  tags        = concat(["homelab"], var.tags)

  unprivileged = var.unprivileged

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
    for_each = (var.ipv4_address != "" || var.hostname != "") ? [1] : []
    content {
      hostname = var.hostname != "" ? var.hostname : null

      dynamic "ip_config" {
        for_each = var.ipv4_address != "" ? [1] : []
        content {
          ipv4 {
            address = var.ipv4_address
            gateway = var.ipv4_gateway
          }
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

  lifecycle {
    ignore_changes = [
      operating_system,
      initialization,
      features,
      mount_point,
    ]
  }
}

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
        "pct config \"$ctid\" | grep -q 'mp=${var.mount_points[0].path}' || {",
        "  pct stop \"$ctid\"",
      ],
      [
        for i, mp in var.mount_points :
        "  pct set \"$ctid\" -mp${i} ${mp.volume},mp=${mp.path}"
      ],
      [
        for mp in var.mount_points : "  mkdir -p ${mp.volume}/ssh"
        if mp.path == "/persist"
      ],
      [
        for mp in var.mount_points : "  chown -R ${mp.owner} ${mp.volume}"
        if mp.owner != null
      ],
      [
        "  pct start \"$ctid\"",
        "}",
      ]
    )
  }
}
