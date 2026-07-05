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
