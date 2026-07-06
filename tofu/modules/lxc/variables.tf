# Per-container inputs. Shared inputs (node, datastore, bridge, template) are
# passed through from the root module so the module stays self-contained.

variable "vm_id" {
  description = "Proxmox CT id for the container."
  type        = number
}

variable "description" {
  description = "Human-readable description shown in the Proxmox UI."
  type        = string
}

variable "tags" {
  description = "Extra tags beyond the shared 'homelab' tag."
  type        = list(string)
  default     = []
}

variable "cores" {
  description = "CPU cores allocated to the container."
  type        = number
}

variable "memory" {
  description = "Dedicated RAM (MB) for the container."
  type        = number
}

variable "swap" {
  description = "Swap (MB). null leaves it at the Proxmox default (no swap)."
  type        = number
  default     = null
}

variable "disk_size" {
  description = "Root disk size (GB)."
  type        = number
}

variable "unprivileged" {
  description = "Whether the container is unprivileged. Privileged containers cannot have their features managed by the API token."
  type        = bool
  default     = true
}

variable "nesting" {
  description = "Enable the nesting feature. Required for systemd inside unprivileged LXCs."
  type        = bool
  default     = true
}

variable "started" {
  description = "Whether the container should be running after apply."
  type        = bool
  default     = true
}

# --- Shared (passed through from the root module) ----------------------------

variable "proxmox_node_name" {
  description = "Proxmox node hosting the container."
  type        = string
}

variable "container_datastore" {
  description = "Datastore for the container root filesystem."
  type        = string
}

variable "network_bridge" {
  description = "Proxmox bridge the container NIC attaches to."
  type        = string
}

variable "template_file_id" {
  description = "Volume id of the NixOS LXC template Tofu boots containers from."
  type        = string
}

variable "mount_points" {
  description = <<-EOT
    Optional host bind mounts to attach to the container. Each entry maps a host
    path (volume) to an in-container path. Bind mounts require root@pam auth,
    which the Proxmox API token cannot provide, so the module applies them via
    `pct set -mp` over root SSH (see proxmox_ssh_host / proxmox_ssh_private_key
    _path) rather than as a native mount_point block. Default: no mount points.
  EOT
  type = list(object({
    volume = string
    path   = string
  }))
  default = []
}

variable "proxmox_ssh_host" {
  description = "Proxmox node address for the root SSH session that applies bind mounts. Required when mount_points is non-empty; unused otherwise."
  type        = string
  default     = ""
}

variable "proxmox_ssh_private_key_path" {
  description = "Path to the root SSH private key (on the Tofu runner) used to apply bind mounts. Required when mount_points is non-empty; unused otherwise."
  type        = string
  default     = ""
}

variable "ipv4_address" {
  description = <<-EOT
    Static IPv4 (CIDR, e.g. "192.168.2.108/24") applied at create time so the
    container boots reachable on its final address — avoids a DHCP-lease hunt
    during bootstrap. Empty (default) = DHCP (the template default). NixOS owns
    networking from the first switch; this only bootstraps the lease. The
    initialization block is in lifecycle.ignore_changes, so the value is
    applied once at create and not reconciled afterward.
  EOT
  type    = string
  default = ""
}

variable "ipv4_gateway" {
  description = "IPv4 gateway for ipv4_address. Required when ipv4_address is set."
  type    = string
  default = ""
}
