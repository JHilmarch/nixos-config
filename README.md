# Jonatan's nixos-config

## Table of Contents

- [Flake](#flake)
  - [Troubleshooting](#troubleshooting)
- [Functions](#functions)
- [Home Modules](#home-modules)
  - [fish](#fish)
  - [git](#git)
  - [gpg](#gpg)
  - [ssh](#ssh)
    - [YubiKey SSH](#yubikey-ssh)
- [Modules](#modules)
  - [NFS](#nfs)
  - [Spotify](#spotify)
  - [systemd](#systemd)
- [Scripts](#scripts)
- [Secrets](#secrets)
- [AI Assistant and MCP](#ai-assistant-and-mcp)
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

### Troubleshooting

If `nixos-rebuild` hangs/crashes:

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

## Functions

Here, custom functions & helper methods can be found. [Ankarhem's](https://github.com/ankarhem/) function gets SSH keys
from a public GitHub profile.

## Home Modules

Modules intended to be used with Home Manager (`home.nix`).

### fish

The module contains the _fish_ shell configurations. It includes the fuzzy finder plugin and smart abbreviations for
common git commands. The shell suggests commands based on history and completions, in color. Read more at
[fishshell.com](https://fishshell.com/).

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

#### YubiKey SSH

```
# Check if FIDO2 is enabled
ykman info
```

Read more on how to set up your YubiKey:

- [Dr Duh's YubiKey-Guide](https://github.com/drduh/YubiKey-Guide)

Using a YubiKey is assumed. The name on your private keys should correspond to the configured identity files.

In Windows; ensure that you have an SSH key.

```powershell
# Search your FIDO credentials for existing SSH keys
ykman fido credentials list -c | ConvertFrom-Csv | Select-Object credential_id, rp_id, user_name, user_display_name | Format-Table -AutoSize
```

If you don't have an SSH key, you can create a new key-pair with this command:

```powershell
ssh-keygen -t ed25519-sk -O resident -O application=ssh:github.com -O verify-required -C "YubiKey 5C NFC 12345678"
```

Logged in to your NixOS host and with the YubiKey connected: Go to your home ssh folder and recreate the SSH keys:

```
cd ~/.ssh/
ssh-keygen -K
```

If the public key is uploaded to GitHub you can test your connection like this:

```
ssh -T git@github.com
```

**Read more**:

- [Yubico: Securing SSH Authentication with FIDO2](https://developers.yubico.com/SSH/Securing_SSH_with_FIDO2.html)
- [Another SSH guide](https://gist.github.com/Kranzes/be4fffba5da3799ee93134dc68a4c67b)

## Modules

Modules intended to be used by system configurations (`{host}/configuration.nix`).

### nfs

A module to configure NFS shares. `fileshare.nix` is setting up common shares at the private NAS
[fileshare.se](http://synology.fileshare.se/).

### spotify

`firewall.nix` is a module used to open up the correct firewall ports for Spotify.

### systemd

#### no-sleep

_Sleep_ and _Hibernation_ is creating problems so a common pattern used is to disable those functions.

#### wake-on-lan

A systemd service enables Wake on LAN with magic package on the network interface. The
[ethtool](https://mirrors.edge.kernel.org/pub/software/network/ethtool/) command is triggered during system boot.

## Scripts

### Reboot to Windows

The `reboot-to-windows.sh` script uses the `bootctl` tool to set Windows as the next UEFI boot entry, then reboots the
system. Since the latest NixOS generation is the default, this script is useful for remotely cold booting into Windows,
for example, after using Wake On LAN.

## Secrets

Here, SOPS secrets are stored, sorted by host.

## AI Assistant and MCP

This repository is set up to work with JetBrains Junie and Claude Code with the Model Context Protocol (MCP).

- The project-level MCP registry lives at: `.junie/mcp/mcp.json`
  - It defines a server named `nixos` that is started with: `mcp-nixos`
  - It defines a server named `context7` that is started with: `context7`

## NixOS

- [NixOS Manual](https://nixos.org/manual/nixos/stable/)
- [Home Manager](https://nix-community.github.io/home-manager/)
- [Package Manager](https://wiki.nixos.org/wiki/Nix_package_manager)
- [Search packages & options](https://search.nixos.org/)
- [Flakes](https://nixos.wiki/wiki/Flakes)

______________________________________________________________________

[Back to top](#jonatans-nixos-config)
