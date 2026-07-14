# cache — the homelab's LAN Nix binary cache LXC.
#
# Tofu creates and sizes the container and attaches its NIC to the Proxmox
# bridge; the container's OS and addressing come from its NixOS flake config
# (hosts/cache/, flake host nixos-cache). Larger disk than edge because it
# stores Nix store artifacts served to the LAN.
#
# The cache's rootfs (and therefore its /nix/store) lives on the bulk
# `hdd-zfs` pool, not the NVMe `local-lvm` pool: the store wants capacity,
# not latency. The `container_datastore` override below is the whole change.

module "cache" {
  source = "./modules/lxc"

  vm_id        = var.cache_vm_id
  hostname     = "homelab-cache"
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
  container_datastore = var.hdd_zfs_storage_id
  network_bridge      = var.network_bridge
  template_file_id    = var.template_file_id

  ipv4_address = "192.168.2.108/24"
  ipv4_gateway = "192.168.2.1"

  mount_points = [
    {
      volume = "/hdd-zfs/keys/cache"
      path   = "/persist"
      owner  = "100000:100000"
    }
  ]
  proxmox_ssh_host             = var.proxmox_ssh_host
  proxmox_ssh_private_key_path = var.proxmox_ssh_private_key_path
}

moved {
  from = proxmox_virtual_environment_container.cache
  to   = module.cache.proxmox_virtual_environment_container.this
}
