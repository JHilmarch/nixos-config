# runners — the homelab's CI build-host LXC.
#
# Tofu creates and sizes the container and attaches its NIC to the Proxmox
# bridge; the container's OS and addressing come from its NixOS flake config
# (hosts/runners/). Storage split (#206): the rootfs (/nix/store, runner
# state) stays on the NVMe local-lvm pool for store latency, while the
# runner's act job cache (fresh hostexecutor workspace per gate run,
# capacity-bound, not latency-sensitive) lives on the encrypted
# hdd-zfs/data/runners dataset via the second bind mount below. The NVMe
# rootfs is capacity-limited; the act cache grew until ENOSPC took the gate
# down. The first bind mount persists only the SSH host key (and the derived
# age identity) across destroy/recreate. Cores are capped at 6, below the
# cache host's 12, so a runaway build cannot starve the fleet. See
# tofu/README.md "Runners act cache on the HDD pool" for the mount path
# rationale (/var/lib/private/gitea-runner, not /var/lib/gitea-runner).

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
      owner  = "100000:100000"
    },
    {
      volume = "/hdd-zfs/data/runners"
      path   = "/var/lib/private/gitea-runner"
      owner  = "100000:100000"
    }
  ]
  proxmox_ssh_host             = var.proxmox_ssh_host
  proxmox_ssh_private_key_path = var.proxmox_ssh_private_key_path
}
