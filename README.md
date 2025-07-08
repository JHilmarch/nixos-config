# Jonatan's nixos-config

## Table of Contents
- [Flake](#flake)
- [Modules](#modules)
  - [git](#git)
  - [gpg](#gpg)
  - [ssh](#ssh)
- [NixOS](#nixos)

## Flake

Contains NixOS configurations for the following targets:
- [orion](./hosts/orion/README-orion.md)
- [iso](./hosts/iso/README-iso.md)

How to target a host:

```
cd ~/nixos-config
sudo nixos-rebuild switch --flake .#nixos-orion && sudo shutdown -h now
```

Change `nixos-orion` to the host you want to target. See the nix [flake](./flake.nix) for details.

How to clean up and remove old generations:

```
sudo nix-env --list-generations --profile /nix/var/nix/profiles/system
#or
sudo nixos-rebuild list-generations
sudo nix-env --delete-generations --profile /nix/var/nix/profiles/system +2
cd [to the nixos-config directory]
sudo nixos-rebuild boot --flake .
```

If `nixos-rebuild` hangs/crashes, because of a full boot partition:

```
sudo nix-store --gc
nix-collect-garbage -d
sudo nix-store --verify --check-contents --repair
nix flake update --commit-lock-file
sudo nixos-rebuild boot --flake .
```

Don't forget to stage, commit or stash your changes before running `nix flake update`.

How to fix malformed database image:

```
cd /nix/var/nix/db
sudo nix-shell -p sqlite

#nix-shell
sudo sqlite3 db.sqlite ".backup 'db.bak.sqlite' "
sudo sqlite3 db.sqlite

#SQLite
sqlite> .output db.sql
sqlite> .dump

#nix-shell
sudo sqlite3 db.new.sqlite < db.sql
sudo mv db.new.sqlite db.sqlite
```

## Modules

### git

The module contains the _git_ configuration. Change `userName`, `userEmail` and `user.signingkey`.

```powershell
# Check if OpenPGP is set up with a signing key on your YubiKey and copy it.
gpg --card-status
```

### gpg

The module contains the _gpg_ configuration. Add your own public keys and set the trust level.

### ssh

The module enables SSH and contains references to the private keys for authentication and GitHub specific configuration.

## NixOS

- [NixOS Manual](https://nixos.org/manual/nixos/stable/)
- [Home Manager](https://nix-community.github.io/home-manager/)
- [Package Manager](https://wiki.nixos.org/wiki/Nix_package_manager)
- [Flakes](https://nixos.wiki/wiki/Flakes)
