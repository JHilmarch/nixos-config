# NixOS on ISO image

## Build

`nix build ~/Code/nixos-config'#nixosConfigurations.iso.config.system.build.isoImage' `

# Make bootable USB

sudo dd if=./jonatan-nixos-24.11-x86_64-linux.iso of=/dev/sda bs=4M status=progress && sync
