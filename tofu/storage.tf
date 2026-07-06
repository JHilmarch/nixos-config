# hdd-zfs — bulk HDD-backed ZFS mirror + encrypted host-key dataset (#166).
#
# The pool itself (mirror of sda+sdb on pve) is a one-time operator step
# OUTSIDE Tofu: the bpg/proxmox provider can register an existing zpool as
# Proxmox storage but cannot create one from disks. See tofu/README.md
# "ZFS pool + encrypted dataset" for the operator sequence.
#
# This file:
#   1. registers the already-existing pool as Proxmox storage, so LXC
#      disk/mount_point blocks can reference it by id;
#   2. declaratively unlocks + mounts the encrypted dataset during apply,
#      using the SOPS-held passphrase (exported as TF_VAR_ by
#      scripts/tofu-sops.fish).
#
# ZFS dataset encryption is a Proxmox-host-level concern. An LXC container
# cannot unlock the dataset (no access to the host's zfs tooling). The
# container only reads its persisted SSH key via a mount point targeting
# its own per-host subdirectory (e.g. hdd-zfs/keys/cache/). Once unlocked
# at the host level, the dataset stays unlocked across container
# destroy/recreate — rebuilds need no password. The passphrase is required
# only at:
#   (a) initial provisioning (here, in Tofu);
#   (b) after a Proxmox host reboot — manual `zfs load-key` (see README).

# ---------------------------------------------------------------------------
# Storage registration
# ---------------------------------------------------------------------------

resource "proxmox_storage_zfspool" "hdd_zfs" {
  # Proxmox storage id — what container disk { datastore_id = ... } references.
  id = var.hdd_zfs_storage_id

  # Proxmox node(s) where this storage is visible.
  nodes = [var.proxmox_node_name]

  # The already-created zpool on pve. Must match the operator step
  # `zpool create ... hdd-zfs ...`.
  zfs_pool = var.hdd_zfs_pool_name

  # rootdir = container root filesystems / mount points.
  # images  = VM disks (qcow2-style). Not strictly needed for LXCs but
  #           costs nothing and lets future VMs use the pool.
  content = ["rootdir", "images"]
}

# ---------------------------------------------------------------------------
# Encrypted dataset unlock + mount (idempotent)
# ---------------------------------------------------------------------------

resource "null_resource" "zfs_keys_unlock" {
  # Re-run only when the passphrase changes (sha256 keeps the value out of
  # state — plain var.homelab_zfs_passphrase would land there in plaintext).
  # Since state is SOPS-encrypted, even plaintext-in-state is acceptable,
  # but the hash is defence-in-depth.
  triggers = {
    passphrase_hash = sha256(var.homelab_zfs_passphrase)
    dataset         = "${var.hdd_zfs_pool_name}/keys"
  }

  connection {
    type        = "ssh"
    user        = "root"
    host        = var.proxmox_ssh_host
    private_key = file(pathexpand(var.proxmox_ssh_private_key_path))
    timeout     = "2m"
  }

  # Write the passphrase to a root-only temp file, then pipe into zfs load-key.
  # The file-provisioner content lands in state (SOPS-encrypted) — preferable
  # to inline `echo '<pass>' | ...` which leaks via the remote process list.
  # Cleaned up by shred -u at the end of remote-exec.
  provisioner "file" {
    content     = var.homelab_zfs_passphrase
    destination = "/root/.zfs-keys-passphrase.tf"
  }

  provisioner "remote-exec" {
    inline = [
      "chmod 600 /root/.zfs-keys-passphrase.tf",
      # Guard: `zfs load-key` is not reliably idempotent across ZFS versions.
      "[ \"$(zfs get -H -o value keystatus ${var.hdd_zfs_pool_name}/keys)\" = \"available\" ] || cat /root/.zfs-keys-passphrase.tf | zfs load-key ${var.hdd_zfs_pool_name}/keys",
      # Guard: `zfs mount` errors on already-mounted filesystems.
      "zfs mount | grep -q '^${var.hdd_zfs_pool_name}/keys '       || zfs mount ${var.hdd_zfs_pool_name}/keys",
      "zfs mount | grep -q '^${var.hdd_zfs_pool_name}/keys/cache ' || zfs mount ${var.hdd_zfs_pool_name}/keys/cache",
      # Cleanup: shred then remove the passphrase file.
      "shred -u /root/.zfs-keys-passphrase.tf",
    ]
  }
}
