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
  description = "Root disk size (GB) for the cache container. Holds every host's full closure plus upstream artifacts; a thin LVM volume, so it only consumes what is used."
  type        = number
  default     = 128
}
