# NixOS on Orion 7000, dual boot host

Configuration and documentation for NixOS dual boot with Windows 11 on Acer Predator Orion 7000.

_**Work in progress...**_

## Handle secrets

### Deploying secrets

The package `sops-nix` is storing secrets decrypted in /nix/store is OK. This is OK for NixOS on my personal machines,
with only one user. This is the package, currently used for decrypt and deploy secrets encrypted with `sops` and `age`.
During the activation stage of *nixos-rebuild*, an age standard access key is used to decrypt the secrets and
[sops-nix](https://github.com/Mic92/sops-nix) is copying them to the /nix/store.

With another related package called [agenix](https://github.com/ryantm/agenix), we can mount the secrets to known paths.
Preferable one path per usage or application, with a strict permission policy. For remote machines or critical
application I plan to use identities derived from SSH-keys and `agenix`, together with a vault to handle secrets.

### Encrypt & decrypt secrets using sops, age & YubiKey

The [YubiKey plugin](https://github.com/str4d/age-plugin-yubikey) for [age](https://github.com/FiloSottile/age), called
`age-plugin-yubikey`, let us generate and export an identity, stored on the YubiKey, under the PIV section:

```bash
ykman piv change-pin
ykman piv change-puk
ykman piv access change-management-key --generate --protect
age-plugin-yubikey --generate
age-plugin-yubikey --identity > \
~/.config/sops/age/id_jonatan.txt
age-plugin-yubikey --list
ykman piv info
```

The YubiKey identity will contain a reference to the hardware key and can be stored openly.

The identity of the age standard access key contains a private key/secret. We should encrypt it with the YubiKey and a
strong password as a backup:

```bash
cd ~/.config/sops/age/
age-keygen -o id_local.txt
age-keygen -y -o r_local.txt id_local.txt
cat id_jonatan.txt >> keys.txt
cat id_local.txt >> keys.txt
# yank or copy YubiKey public key manually to r_jonatan.txt
cat r_local.txt >> recipients.txt
cat r_jonatan.txt >> recipients.txt
age -R recipients.txt id_local.txt > id_local.age
age -R recipients.txt keys.txt > keys.age
rm id_local.txt
rm keys.txt
# Before development session
age -d -i id_jonatan.txt -o keys.txt keys.age
# Before build
# Uncomment the YubiKey identity in keys.txt. sops-nix will not
# interact with the user and fail the build otherwise.
# After development session
rm keys.txt
```

The file `keys.txt` in the home age configuration folder is used to lookup age identities.

After keys in .sops.yaml changed, we re-**encrypt** the secret files:

```bash
sops updatekeys secrets/nixos-orion-7000/secrets.yml
```

[sops](https://github.com/getsops/sops) keys and creation rules allow both the user 'jonatan-yubikey-23839166' and the
host 'local' to **decrypt** secrets under secrets/nixos-orion-7000:

```bash
sops secrets/nixos-orion-7000/secrets.yml
```

To check the secret in the nix store after rebuild:

```bash
sudo cat /run/secrets/secret1
```

---

## Logbook

> **2025-03-05**
>
> INSTALLATION
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

> **2025-03-09**
>
> CREATING A FLAKE
>
> I added some basic configuration with flakes and home manager. I'm happy that the Nvidia open drivers seems to work
> fine. I had to delete nix-index and nix-index-database. I think I need the packages, so I will try to add them again.
> Also the nvim and fish configuration, generated by a LLM was not working. So at least four things on my immediate TODO
> list.
>
> The boot hangs sometimes and I need to hard restart. Another bad thing is that the time in Windows keep getting out of
> sync. I think I need to merge the two EFI boot partitions into one.

> **2025-03-11**
>
> MERGING BOOT PARTITIONS
>
> - Moved EFI-files from NIXBOOT partition to Windows ESP partition
> - Removed old NIXBOOT partition
> - In Windows: Changed boot manager with terminal command
> `bcdedit /set "{bootmgr}" path "\EFI\systemd\systemd-bootx64.efi"`
> - In Windows: Fixed time issue:
> `reg add "HKEY_LOCAL_MACHINE\System\CurrentControlSet\Control\TimeZoneInformation" /v RealTimeIsUniversal /d 1 /t REG_DWORD /f`

> **2025-03-15**
>
> FIXING ISSUES AND ENABLING BLUETOOTH
>
> - Using fish as shell
> - Fixed GPG configuration, by moving it to home.
> - Removed double load of home.nix, causing errors
> - Enabled Bluetooth. Use `bluetoothctl` to follow live logs. If the controller isn't available, try:
> ```bash
> sudo modprobe -r btusb
> sudo modprobe -r btintel
> sudo modprobe btusb
> sudo modprobe btintel
> ```
> - Active kernel modules can be verified by `lsmod | grep bluetooth`

> **2025-03-17**
>
> TILING WINDOWS
>
> I've struggeling a lot with a tiling window setup. I couldn't get Hyprland to work, so I have to come back to that
> at a later point. I'm now using the GNOME extension tiling-shell, with shortcuts for opening workspaces and apps.

> **2025-04-04**
>
> MOUNTING SHARES
>
> I wanted to mount my Synology DiskStation SMB/CIFS shares without success. As an alternative I activated NFS.
>
> Note: The directories for the mounting point is not created by the nix flake setup. Ideally, I want the folders
> to be created in an early boot stage.


> **2025-04-16**
>
> NVIDIA
>
> The Nvidia drivers are not handling 'suspend' as expected, so I disabled the function.

> **2025-05-20**
>
> NEW MOTHERBOARD - FAN CONTROL
>
> I fucked up the motherboard by hard reset during ME firmware update and had to buy a new motherboard.
> No spare parts was available, so I ordered and installed a Asus Prime Z790-P Wifi board. A header is missing to
> control a fan or led.
>
> Installed and configured CoolerControl. Here is documentation of how to restore the backup:
> https://docs.coolercontrol.org/wiki/config-files.html#backup-import

> **2025-05-24**
>
> SECURE BOOT WITH Lanzaboote
>
> I put the UEFI Secure Boot in "setup" mode, generated keys with `sbctl` migrated them from /etc/secureboot to
> /var/lib/sbctl. Finally, the keys were enrolled to the motherboard and the UEFI Windows Secure Boot was activated.
> I can log in to Windows but NixOS boot gives me an error saying that 'Kernel hash has no match',
> or something like that. The message is only visible for a second so it's hard to read it word for word.
>
> Command to sign all keys under /boot: `sbctl verify | sed 's/✗ /sbctl sign -s /e'`
>


