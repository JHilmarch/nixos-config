# Notes and installation guidelines

## Orion (New formatted Linux filesystem partition, encrypted with LUKS)

### List discs and partitions

`lsblk -o NAME,SIZE,TYPE,FSTYPE,LABEL,MOUNTPOINT,UUID`

### Open the encrypted LINUX filesystem partition

`sudo cryptsetup luksOpen /dev/disk/by-uuid/{uuid} encrypted-nix-root`

### Check partitions and filesystem

If the NixOS root filesystem is formatted; change the uuid in the git repository (preferable from another machine).

### Mounted partitions

```
sudo mount /dev/disk/by-label/NIXROOT /mnt
sudo mkdir -p /mnt/boot
sudo mount /dev/disk/by-label/ESP /mnt/boot
```

## Download nixos-config

```
cd /mnt/
git clone https://github.com/JHilmarch/nixos-config.git
```

### Install

```
sudo nixos-install --flake /mnt/nixos-config#nixos-orion-7000
```
