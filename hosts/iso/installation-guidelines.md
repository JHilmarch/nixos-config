# Notes and installation guidelines

## Orion (New formatted Linux filesystem partition, encrypted with LUKS)

### List discs and partitions

`lsblk -o NAME,SIZE,TYPE,FSTYPE,LABEL,MOUNTPOINT,UUID`

### Open the encrypted LINUX filesystem partition

`sudo cryptsetup luksOpen /dev/disk/by-uuid/{uuid} encrypted-nix-root`

### Mounted partitions

```
sudo mount /dev/disk/by-label/NIXROOT /mnt
sudo mkdir -p /mnt/boot
sudo mount /dev/disk/by-label/ESP /mnt/boot
```

### Generate the configuration files

`sudo nixos-generate-config --force --root /mnt`

### Edit the nix configuration with vim:

```
sudo vim /mnt/etc/nixos/configuration.nix
sudo vim /mnt/etc/nixos/hardware-configuration.nix
```

- `time.timeZone = "Europe/Stockholm";`
- `boot.supportedFilesystems = [ "ntfs" ];`
- `swapDevices = [ { device = "/dev/disk/by-label/NIXSWAP"; } ];`
- `nixpkgs.config.allowUnfree = true;`

- Language

```
i18n.defaultLocale = "sv_SE.UTF-8";
console = {
    font = "Lat2-Terminus16";
    useXkbConfig = true;
};
```

- xserver

```
xserver = {
  enable = true;
  xkb.layout = "se";
  videoDrivers = [ "nvidia" ];
};

```

- Boot changes

```
boot = {
    supportedFilesystems = [ "ntfs" ];
    loader = {
        systemd-boot.enable = true;
        efi.canTouchEfiVariables = true;
    };

    initrd = {
      availableKernelModules = [ "vmd" "xhci_pci" "ahci" "nvme" "usbhid" "usb_storage" "uas" "sd_mod" ];
      supportedFilesystems = [ "nfs" ];
      kernelModules = [ "nfs" ];
    };

    kernelModules = [ "kvm-intel" "btusb" "btintel" ];
    extraModulePackages = [ ];
};
```

- Nix Flakes

```
nix = {
    settings.experimental-features = ["nix-command" "flakes"];
    extraOptions = "experimental-features = nix-command flakes";
};
```

### Install

```
cd /mnt/
sudo nixos-install
```

### Set passwords

Set password than prompted for root.

After starting from the new revision:
- Ctrl-Alt-F1 to open getty terminal (Alt-F7 to switch back to X)
- Mount USB with dotfiles/nixos-config, copy to home and rebuild with flakes.
