# runners — the homelab's CI build-host LXC.
#
# Tofu creates and sizes the container and attaches its NIC to the Proxmox
# bridge; the container's OS and addressing come from its NixOS flake config
# (hosts/runners/). The rootfs (the build working set) stays on the NVMe
# local-lvm pool; the single bind mount below persists only the SSH host key
# (and the derived age identity) across destroy/recreate — no data or NAS
# mounts. Cores are capped at 6, below the cache host's 12, so a runaway
# build cannot starve the fleet.

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
  container_datastore = var.container_datastore
  network_bridge      = var.network_bridge
  template_file_id    = var.template_file_id

  ipv4_address = "192.168.2.110/24"
  ipv4_gateway = "192.168.2.1"

  mount_points = [
    {
      volume = "/hdd-zfs/keys/runners"
      path   = "/persist"
    }
  ]
  proxmox_ssh_host             = var.proxmox_ssh_host
  proxmox_ssh_private_key_path = var.proxmox_ssh_private_key_path
}
