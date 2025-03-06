# Orion 7000 dual boot host

Configuration and documentation for NixOS dual boot with Windows 11 on Acer Predator Orion 7000.

---

_**Work in progress...**_

## Logbook

> **2025-03-05**
> 
> Using MiniTool Partition Wizard Free 12.9
> - Shrunk C drive, leaving 400 GB unallocated space
> - Expanded the ESP partition to 1,5 GB (changes loaded and performed before next boot)
> 
> My original plan was to use on ESP boot partition on the disk, also for NixOS boot, but I ended up with two. It's not
> ideally, but the dual boot works for now so I'm not touching it.
>
> Using RUFUS 4.6
> - Downloaded NixOS ISO GUI version (Gnome, 64-bit Intel/AMD)
> - Partition scheme GPT
> - Check device for blocks
> - Everything else default (FAT32)
> 
> Alternative tools for creating the bootable USB are for example balenaEtcher and Ventoy.
> The partition schema doesn't need to be GPT,
> and download the "Minimal ISO" instead of the GUI alternatives. The GUI installation doesn't work and hangs on 46 %.
> 
> In Windows
> - Disabled the hibernation feature (fast boot)
> 
> I read that this is recommended.
> 
> In UEFI ("BIOS")
> - Disabled secure boot
> 
> I hope I can find configuration, so I can enable secure boot again.
> 
> Installation
> - Rebooted into NixOS installation USB
> - Closed down installation GUI wizard
> - Opened console
> - Used `lsblk` with and without the -f flag and `sudo fdisk -l` to list disks and partition table
> - Used [**fdisk**](https://www.man7.org/linux/man-pages/man8/fdisk.8.html) to create partitions
>   - Targeted correct disk: `sudo fdisk /dev/nvme0n1`
>   - `n` to create partition
>   - `t` to change partition type
>   - `w` to write changes
>   - Created EFI partition (1 GB)
>     - Formatted as FAT32: `sudo mkfs.fat -F 32 /dev/nvme0n1p4`
>     - Labeled NIXBOOT: `sudo fatlabel /dev/nvme0n1p4 NIXBOOT`
>   - Created SWAP partition (16 GB)
>     - Formatted as SWAP: `sudo mkswap /dev/nvme0n1p5`
>     - Labeled NIXSWAP: `sudo swaplabel -L SWAP /dev/nvme0n1p5`
>     - Enabled the SWAP: `sudo swapon /dev/nvme0n1p5` (swapoff to disable)
>   - Created ROOT partition (filled up unallocated space)
>     - Formatted as BTRFS: `sudo mkfs.btrfs /dev/nvme0n1p6`
>     - Labeled NIXROOT: `sudo btrfs filesystem label /dev/nvme0n1p6 NIXROOT`
> - Mounted partitions
>   - `sudo mount /dev/disk/by-label/NIXROOT /mnt`
>   - `sudo mkdir -p /mnt/boot`
>   - `sudo mount /dev/disk/by-label/NIXBOOT /mnt/boot`
> - Generated nix configuration templates: `sudo nixos-generate-config --root /mnt`
> - Edited nix configuration with vim: `sudo -e /mnt/etc/nixos/configuration.nix` (and hardware-configuration.nix)
>   - Followed the (poor) installation guide: https://nixos.wiki/wiki/NixOS_Installation_Guide
>   - `services.xserver.xkb.layout = "se";`
>   - Included import `./hardware-configuration.nix`
>   - Changed user configuration
>   - Enabled NTFS support: `boot.supportedFilesystems = [ "ntfs" ];`
>   - Added swap partition: `swapDevices = [ "/dev/disk/by-label/NIXSWAP" ];`
>   - Uncommented other stuff for UEFI and more...
> - Completed installation with `sudo nixos-install` in /mnt
>   - Entered password to use for root
> - Copied Windows EFI files from Windows ESP partition to new NIXBOOT partition
> ```shell
> sudo mkdir -p /mnt/windows-efi
> sudo mkdir -p /mnt/nixos-efi
> sudo mount /dev/nvme0n1p1 /mnt/windows-efi
> sudo mount /dev/nvme0n1p2 /mnt/nixos-efi
> sudo cp -r /mnt/windows-efi/EFI/Microsoft /mnt/nixos-efi/EFI/
> sudo cp -r /mnt/windows-efi/EFI/Boot /mnt/nixos-efi/EFI/
> ```

