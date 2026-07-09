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
# Bind-mounted key material is chowned to 100000 (the unprivileged-LXC subuid
# base) so it maps to in-container root: sshd and sops-nix run as container-root
# and cannot read a host-root/nobody-owned key, which crash-loops sshd and
# breaks secret decryption on first boot.
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

  # See tofu/README.md "Nesting requirement" and "Per-container key persistence mount".
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
      # Map key material to container-root before start (see header).
      [
        for mp in var.mount_points :
        "  mkdir -p ${mp.volume}/ssh && chown -R 100000:100000 ${mp.volume}"
      ],
      [
        "  pct start \"$ctid\"",
        "}",
      ]
    )
  }
}
