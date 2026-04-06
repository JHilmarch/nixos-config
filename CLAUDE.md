# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repository Structure

NixOS flake-based configuration with four hosts:

- **nixos-orion** - Desktop (GNOME, NVIDIA, LUKS+FIDO2, YubiKey, dual boot)
- **wsl-cab** - WSL development environment
- **iso** - Installation ISO image
- **hl-jump** - Proxmox LXC/VM jump host

```
hosts/              # Per-host configuration.nix + home.nix
modules/            # System-level NixOS modules (defaults, context7, markitdown-mcp,
                    #   nfs, spotify, systemd/*)
home-modules/       # Home Manager modules (claude, fish, git, gpg, ssh, xorg)
packages/           # Custom packages exposed as pkgs.local.<name>
templates/          # Host templates (common, desktop, server, proxmox-lxc)
users/              # User definitions (jonatan)
functions/          # Shared helper functions (GitHub SSH key fetcher)
tools/              # Fish scripts (update-packages, gh-project-manager)
scripts/            # Shell scripts (reboot-to-windows.sh)
secrets/            # SOPS-encrypted secrets (never read or edit)
```

## Flake Architecture

Four nixosConfigurations in flake.nix. Each host receives specialArgs: inputs, self, username, hostname. Orion
additionally receives pkgs-unstable, pkgs-pinned, functions. hl-jump receives functions.

Key inputs: nixpkgs (25.11), nixpkgs-unstable, nixpkgs-pinned, home-manager, sops-nix, nixos-wsl, nix-index-database,
NUR.

Home Manager integrated per-host with extraSpecialArgs. Custom packages in packages/ exposed via overlay as
pkgs.local.<name>.

## Behavioral Rules

### MCP Integration

- **nixos**: Always use proactively for Nix package/option/program searches.
- **context7**: Use for library/API docs, but ask first.
- **github-personal**: Default for all personal GitHub operations.
- **github-work**: Only when explicitly told something is work-related.
- **nuget**: Always use proactively for NuGet package searches.
- **ms-learn**: Always use proactively for Microsoft official documentation.
- **markitdown**: Always use proactively to convert documents to markdown.

### Terminal & Conventions

- Provide commands for fish shell.

## Domain Knowledge

- **Secrets**: All files in secrets/ are SOPS-encrypted with age. Never read or edit.
- **Dual Boot**: Orion has Windows dual boot; scripts/reboot-to-windows.sh uses bootctl to set the next UEFI boot entry.
- **YubiKey**: Used for SSH (FIDO2) and GPG. See README.md for setup.
- **NFS**: modules/nfs/fileshare.nix configures shares for private NAS at fileshare.se.
- **Claude Code**: Configured via home-modules/claude/ with wrapper scripts.
