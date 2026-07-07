# Provisioning inputs — nothing host-specific is hardcoded in the resources.

variable "proxmox_node_name" {
  description = "Proxmox node that hosts the homelab LXCs (pvesh get /nodes)."
  type        = string
  default     = "pve"
}

variable "template_datastore" {
  description = "Datastore holding the NixOS LXC CT template (see templates/README.md)."
  type        = string
  default     = "local"
}

variable "template_file_id" {
  description = "Volume id of the NixOS LXC template Tofu boots containers from (fixed, stable name)."
  type        = string
  default     = "local:vztmpl/nixos-homelab-lxc.tar.xz"
}

variable "container_datastore" {
  description = "Datastore for the containers' root filesystem."
  type        = string
  default     = "local-lvm"
}

variable "network_bridge" {
  description = "Proxmox bridge the container NIC attaches to."
  type        = string
  default     = "vmbr0"
}

# --- edge host ---------------------------------------------------------------

variable "edge_vm_id" {
  description = "Proxmox CT id for the edge container."
  type        = number
  default     = 107
}

variable "edge_cores" {
  description = "CPU cores for the edge container."
  type        = number
  default     = 2
}

variable "edge_memory" {
  description = "Dedicated RAM (MB) for the edge container."
  type        = number
  default     = 2048
}

variable "edge_disk_size" {
  description = "Root disk size (GB) for the edge container."
  type        = number
  default     = 8
}

# --- cache host --------------------------------------------------------------

variable "cache_vm_id" {
  description = "Proxmox CT id for the cache container."
  type        = number
  default     = 108
}

variable "cache_cores" {
  description = "CPU cores for the cache container. All host cores — LXC shares CPU and never reserves it, so nix builds parallelize fully."
  type        = number
  default     = 12
}

variable "cache_memory" {
  description = "RAM ceiling (MB) for the cache container. Used only during builds; LXC does not pre-reserve it. Leaves headroom for the host + other LXCs."
  type        = number
  default     = 40960
}

variable "cache_swap" {
  description = "Swap (MB) for the cache container — a spike margin so heavy nix builds are not OOM-killed."
  type        = number
  default     = 4096
}

variable "cache_disk_size" {
  description = "Root disk size (GB) for the cache container. Holds every host's full closure plus upstream artifacts. Lives on the bulk `hdd-zfs` ZFS mirror pool (ZFS is thin-provisioned, so it only consumes what is used) — not the NVMe `local-lvm` pool."
  type        = number
  default     = 512
}

# --- ZFS mirror pool + encrypted dataset (#166) ------------------------------

variable "hdd_zfs_pool_name" {
  description = "Name of the ZFS mirror pool created by the operator on pve (matches `zpool create <name> ...`)."
  type        = string
  default     = "hdd-zfs"
}

variable "hdd_zfs_storage_id" {
  description = "Proxmox storage id under which the pool is registered. Container disk/mount_point blocks reference this as datastore_id."
  type        = string
  default     = "hdd-zfs"
}

variable "proxmox_ssh_host" {
  description = "Hostname/IP of the Proxmox node for SSH-based remote-exec (zfs load-key, etc.). Auto-derived from the Proxmox API endpoint by scripts/tofu-sops.fish (TF_VAR_proxmox_ssh_host)."
  type        = string
}

variable "proxmox_ssh_private_key_path" {
  description = "Path to a non-FIDO2 SSH private key for remote-exec into the Proxmox node. YubiKey/FIDO2 keys don't work here because the provisioner's SSH connection is non-interactive (can't prompt for touch/PIN)."
  type        = string
  default     = "~/.ssh/id_ed25519_tofu"
}

variable "homelab_zfs_passphrase" {
  description = "Passphrase for the hdd-zfs/keys encrypted ZFS dataset (SOPS key: homelab-zfs-passphrase). Sourced via TF_VAR_homelab_zfs_passphrase (exported by scripts/tofu-sops.fish)."
  type        = string
  sensitive   = true
}
