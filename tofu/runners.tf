# runners — the homelab's CI build-host LXC.
#
# Tofu creates and sizes the container and attaches its NIC to the Proxmox
# bridge; the container's OS and addressing come from its NixOS flake config
# (hosts/runners/). The rootfs (and therefore /nix/store) lives on the bulk
# hdd-zfs pool, not the NVMe local-lvm pool — the same layout as the cache
# host. The store wants capacity, not latency: each gate run builds 5 host
# toplevels (orion alone is ~30 GiB unpacked) and the store accumulates
# without bound between weekly GC, so the small NVMe rootfs filled in a
# single run (#206). The runner's build time is dominated by LAN
# substitution (cache.fileshare.se at ~100 MB/s), not local store reads,
# so spinning disk is fine — the cache host has run this layout for weeks
# without issue. The container_datastore override below is the whole change.
#
# Cores are capped at 6, below the cache host's 12, so a runaway build
# cannot starve the fleet.

module "runners" {
  source = "./modules/lxc"

  vm_id        = var.runners_vm_id
  hostname     = "homelab-runners"
  description  = "Homelab CI build host (runners). Managed by OpenTofu; OS owned by hosts/ flake config."
  tags         = ["runners"]
  cores        = var.runners_cores
  memory       = var.runners_memory
  swap         = var.runners_swap
  disk_size    = var.runners_disk_size
  unprivileged = true
  nesting      = true
  started      = true

  proxmox_node_name   = var.proxmox_node_name
  container_datastore = var.hdd_zfs_storage_id
  network_bridge      = var.network_bridge
  template_file_id    = var.template_file_id

  ipv4_address = "192.168.2.110/24"
  ipv4_gateway = "192.168.2.1"

  mount_points = [
    {
      volume = "/hdd-zfs/keys/runners"
      path   = "/persist"
      owner  = "100000:100000"
    }
  ]
  proxmox_ssh_host             = var.proxmox_ssh_host
  proxmox_ssh_private_key_path = var.proxmox_ssh_private_key_path
}
