# forge — the homelab's git forge LXC.
#
# Tofu creates and sizes the container and attaches its NIC to the Proxmox
# bridge; the container's OS and addressing come from its NixOS flake config
# (hosts/forge/ — Forgejo on a local PostgreSQL). The rootfs (state dir + DB)
# stays on NVMe; git repositories live on the encrypted hdd-zfs/data/forge
# dataset via the second bind mount below. The third bind mount carries the
# restic backup repository: the Proxmox host mounts the Synology NAS (an
# unprivileged LXC cannot NFS-mount itself) and bind-mounts it in, so restic
# writes to a plain local path. See tofu/README.md "NAS-backed backup mount".

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

  mount_points = [
    {
      volume = "/hdd-zfs/keys/forge"
      path   = "/persist"
    },
    {
      volume = "/hdd-zfs/data/forge"
      path   = "/var/lib/forgejo-repos"
    },
    {
      volume = "/mnt/nas-forge-backup"
      path   = "/var/lib/forgejo-backup-repo"
    }
  ]
  proxmox_ssh_host             = var.proxmox_ssh_host
  proxmox_ssh_private_key_path = var.proxmox_ssh_private_key_path
}
