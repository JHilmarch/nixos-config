# NixOS Installation Guide - ThinkPad P51

This guide covers the complete installation of NixOS on the Lenovo ThinkPad P51 with BTRFS and LUKS encryption.

## Prerequisites

- Bootable USB with NixOS installer
- Network connection (Ethernet or existing USB tethering)
- This repository cloned
- YubiKey (optional, for FIDO2 unlock)

## Package Availability

**Important:** The NixOS installation USB is a minimal environment. Most packages listed in this configuration (dotnet
SDKs, JetBrains Rider, communication apps, etc.) are NOT available on the USB. They will be installed automatically when
you run `nixos-install --flake .#nixos-p51`.

The USB only provides basic tools for installation. All configured packages from your `home.nix` and `configuration.nix`
will be installed and available after the first boot into your new system.

## Current Partition Layout

```
nvme0n1
├─nvme0n1p1  vfat (EFI boot)     → /boot/efi
└─nvme0n1p2  crypto_LUKS        → ext4 (root)
```

## Target Partition Layout

```
nvme0n1
├─nvme0n1p1  vfat, ESP label, ~512M   → /boot
└─nvme0n1p2  crypto_LUKS, btrfs, rest → /
```

## Installation Steps

### 1. Boot from USB

Boot from your NixOS installation USB and press Enter to continue.

### 2. Setup GitHub Authentication with nix-auth (Recommended)

Before cloning the repository, authenticate with GitHub using nix-auth to access private repositories and flakes:

```bash
# Run nix-auth from the flake inputs
nix run github:nixos-flakes/nix-auth -- login

# Follow the prompts to authenticate with GitHub
# This will store your token for subsequent git operations
```

If nix-auth is not available, you can use traditional git authentication:

```bash
# Configure git credentials (will be prompted for password)
git config --global credential.helper store

# Or use SSH if you have SSH keys set up
git config --global url."ssh://git@github.com/".insteadOf "https://github.com/"
```

### 3. Clone Repository

```bash
# Clone the repository (using nix-auth if configured)
cd /root
git clone https://forge.fileshare.se/jonatan/nixos-config.git
cd nixos-config
```

### 4. Verify Disk

```bash
# Verify disk name
lsblk
```

### 5. Wipe and Create New Partitions

```bash
# Wipe existing partitions
wipefs -a /dev/nvme0n1

# Create new GPT partition table
sgdisk /dev/nvme0n1 -o

# Create EFI partition (512M, EFI System Partition type)
sgdisk /dev/nvme0n1 -n 1:0:+512M -t 1:EF00

# Create root partition (remaining space, Linux filesystem type)
sgdisk /dev/nvme0n1 -n 2:0:0 -t 2:8300

# Print partition table
sgdisk /dev/nvme0n1 -p
```

### 6. Setup LUKS Encryption

```bash
# Encrypt the root partition with FIDO2 (YubiKey support)
cryptsetup luksFormat --type luks2 \
  --pbkdf argon2i \
  --cipher aes-xts-plain64 \
  --key-size 512 \
  --hash sha256 \
  --fido2-device=auto \
  /dev/nvme0n1p2

# Open the encrypted partition
cryptsetup open /dev/nvme0n1p2 luks-4a6bf80a-6ae0-456c-8930-d9957542b4b7

# Verify it's open
lsblk
```

### 7. Format Filesystems

```bash
# Format EFI partition as vfat with ESP label
mkfs.vfat -F 32 -n ESP /dev/nvme0n1p1

# Format root as btrfs with NIXROOT label
mkfs.btrfs -L NIXROOT /dev/mapper/luks-4a6bf80a-6ae0-456c-8930-d9957542b4b7
```

### 8. Mount Filesystems

```bash
# Mount root filesystem
mount /dev/mapper/luks-4a6bf80a-6ae0-456c-8930-d9957542b4b7 /mnt

# Mount boot partition
mkdir -p /mnt/boot
mount /dev/nvme0n1p1 /mnt/boot

# Verify mounts
mount | grep /mnt
```

### 9. Build and Install NixOS

```bash
# Build the system (all packages will be installed now)
nixos-install --flake .#nixos-p51

# If build fails due to missing secrets, you may need to:
# - Copy secrets from a backup location
# - Create minimal secrets for first boot
# - Temporarily disable secret-dependent configurations

# Set root password
nixos-enter
passwd root
exit
```

### 10. Post-Installation

```bash
# Reboot into the new system
reboot

# After boot:
# - Remove USB
# - You'll be prompted for LUKS password
# - Login with your username
# - All configured packages are now available
```

## YubiKey Setup for LUKS Unlock

### Enable YubiKey FIDO2 Unlock

The configuration includes FIDO2 support. To set it up:

1. **Register YubiKey with LUKS:**

```bash
# Add YubiKey as additional unlock method
sudo cryptsetup luksAddToken /dev/nvme0n1p2 \
  --fido2-device=auto \
  --key-slot 1
```

2. **Test YubiKey unlock:**

```bash
# Lock the partition
sudo cryptsetup close luks-4a6bf80a-6ae0-456c-8930-d9957542b4b7

# Test FIDO2 unlock
sudo cryptsetup open --fido2-device=auto /dev/nvme0n1p2 luks-test
```

### Booted SSH (remote access)

The P51 is always unlocked locally with the FIDO2 YubiKey at boot, so initrd SSH is intentionally **not** used. After
the system finishes booting, you can SSH in as `jonatan` from another machine. Authorized keys are pulled from
`https://github.com/JHilmarch.keys` (see `functions.ssh.getGithubKeys` in `configuration.nix`), which includes the FIDO2
YubiKey-resident keys.

#### Client SSH configuration

On the Arch client, add a `Host p51` entry to `~/.ssh/config`. The P51 has a dynamic IP, so target its local DNS name
`nixos-p51.lan` (resolved by the router) instead of a hard-coded address:

```
Host p51
      HostName nixos-p51.lan
      User jonatan
      IdentitiesOnly yes
      IdentityFile ~/.ssh/id_ed25519_sk_rk_github.com
      ForwardAgent no
```

Then connect with:

```bash
ssh p51
```

## Configuration Details

### Hardware Modules

- **NVIDIA Prime** - Optimus GPU switching
- **Intel Kaby Lake** - CPU microcode and optimization
- **Throttled** - Thermal management

### Enabled Features

- **GNOME Desktop** - Full desktop environment
- **Firefox** - Default browser (systemd user service)
- **1Password** - Password manager with GUI and CLI
- **Claude & OpenCode** - AI development tools
- **BTRFS** - With compression and snapshots
- **LUKS** - Full disk encryption with FIDO2 support

### System Packages (Installed after nixos-install)

**Development:**

- dotnet SDKs (9 & 10)
- Node.js 24
- JetBrains Rider
- NuGet

**CLI Tools:**

- git, ripgrep, jq, curl, wget
- findutils, zip, unzip
- sops, age, cryptsetup, sbctl

**Hardware:**

- usbutils, pciutils, lm_sensors
- bluez, pipewire

**Multimedia:**

- VLC, GNOME multimedia apps

### Home Manager Packages (Available after first boot)

**Communication:**

- Element Desktop, Slack, Signal, Discord

**Development:**

- fish-lsp, biome, alejandra, mdformat
- tree-sitter, grc

**YubiKey:**

- yubikey-manager, yubico-piv-tool, libfido2
- age-plugin-yubikey

**Security:**

- 1Password GUI & CLI
- gitleaks

**LLM Agents:**

- ck (hybrid code search)
- nix-auth (Nix authentication tokens)

## Maintenance

### BTRFS Snapshots

```bash
# List snapshots
sudo btrfs subvolume list / | grep snapshot

# Create snapshot
sudo btrfs subvolume snapshot / /snapshot-$(date +%Y%m%d)

# Rollback to snapshot (boot from live USB)
sudo mount /dev/mapper/luks-root /mnt
sudo btrfs subvolume snapshot -r /mnt/root/@ /mnt/@backup
```

### LUKS Backup

```bash
# Backup LUKS header
cryptsetup luksHeaderBackup /dev/nvme0n1p2 \
  --header-backup-file /root/luks-header-backup.bin

# Store backup securely (USB, cloud, etc.)
```

### Update System

```bash
# Rebuild with flake
sudo nixos-rebuild switch --flake /etc/nixos#nixos-p51

# Test changes before applying
sudo nixos-rebuild test --flake /etc/nixos#nixos-p51

# Rollback if needed
sudo nixos-rebuild rollback --flake /etc/nixos#nixos-p51
```

## Additional Resources

- [NixOS Manual](https://nixos.org/manual/nixos/stable/)
- [NixOS Options Search](https://search.nixos.org/options)
- [NixOS Hardware](https://github.com/NixOS/nixos-hardware)
- [BTRFS Wiki](https://btrfs.wiki.kernel.org/)
- [LUKS Documentation](https://gitlab.com/cryptsetup/cryptsetup/-/wikis/home)
