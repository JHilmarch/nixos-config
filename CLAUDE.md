# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repository Structure

This is a NixOS flake-based configuration repository with multiple hosts:

- **`nixos-orion`** - Main desktop (NixOS dual boot with Windows, LUKS+FIDO2, YubiKey, GNOME, NVIDIA)
- **`wsl-cab`** - WSL configuration for development
- **`iso`** - Installation ISO image

```
hosts/              # Host-specific configurations (configuration.nix, home.nix, README-*.md)
modules/            # Reusable NixOS system modules
home-modules/       # Home Manager modules (user-level config)
overlays/           # Custom package overlays (context7, awesome-copilot, MCP servers)
functions/          # Shared helper functions (e.g., GitHub SSH key fetcher)
scripts/            # Helper scripts (e.g., reboot-to-windows.sh)
secrets/            # SOPS-encrypted secrets (never read/edit these)
.junie/mcp/         # JetBrains Junie MCP server configuration
```

## Flake Architecture

The flake defines three NixOS configurations in `flake.nix`. Each host receives `specialArgs`:

- `pkgs-unstable` - Unstable nixpkgs channel (orion only)
- `inputs` - Flake inputs (nixpkgs, home-manager, sops-nix, etc.)
- `self` - Reference to this flake
- `username` and `hostname` - Host identification
- `functions` - Custom helper functions (orion only)

Home Manager is integrated per-host with `extraSpecialArgs` passed through.

## Module System

- **`modules/`** - System-level NixOS modules (imported in host `configuration.nix`)

  - `defaults.nix` - Default settings (timezone, Nix config)
  - `nfs/` - NFS shares
  - `spotify/` - Firewall rules
  - `systemd/` - Custom services (no-sleep, wake-on-lan, flatpak)
  - `claude/` - Claude Code configuration
  - `context7/` - Context7 AI tool integration

- **`home-modules/`** - Home Manager modules (imported in host `home.nix`)

  - `fish/` - Fish shell with fuzzy finder and git abbreviations
  - `git/` - Git with GPG signing
  - `gpg/` - GPG configuration
  - `ssh/` - SSH with YubiKey support
  - `xorg/` - X11 settings

## Development Commands

```bash
# Format code (REQUIRED before committing)
alejandra .                      # Format all Nix files
mdformat .                       # Format markdown files
git diff --name-only --cached -- '*.nix' | xargs -r alejandra -q    # Staged only
git diff --name-only --cached -- '*.md' | xargs -r mdformat          # Staged only

# Validate
nix flake check                  # Run flake checks
sudo nixos-rebuild test --flake .#nixos-orion    # Test build for host
nix build .#nixosConfigurations.iso.config.system.build.isoImage  # Build ISO

# Apply configuration
sudo nixos-rebuild switch --flake .#nixos-orion  # Switch to new config
sudo nixos-rebuild boot --flake .                # Set as boot entry
```

## Conventional Commits

Use Conventional Commits format with scope as the host/module:

```
feat(orion): add systemd no-sleep module
fix(wsl-cab): correct PATH configuration
chore(context7): update to latest version
```

- Subject line must be at most 50 characters.
- Leave a blank line between subject and body.
- The body lines should be at most 72 characters.

## MCP Integration

The repository uses MCP (Model Context Protocol) with servers configured in `.junie/mcp/mcp.json`:

- `nixos` - NixOS package/option search via `mcp-nixos`
  - Always use NixOS MCP when I need to search for Nix community flakes, Nix packages, options or programs without me
    having to explicitly ask.
- `context7` - Context7 AI tool
  - Use Context7 MCP when I need library/API documentation, code generation, setup or configuration steps but explicitly
    ask first.
- `github` - GitHub integration
- `nuget-mcp-server` - .NET/NuGet packages
  - Always use the NugGet MCP when I need to search for NuGet packages without me having to explicitly ask.
- `ms-learn` - Microsoft Learn MCP
  - Always use the ms-learn MCP for up to date Microsoft's official documentation without me having to explicitly ask.
  - Use the ms-learn MCP to fetch a complete article and search through code samples.

## Terminal

When giving guidelines for commands to be used in the Terminal, make them available to be run in fish shell.

## Important Notes

- **Secrets**: All secrets in `secrets/` are SOPS-encrypted with age. Never attempt to read or edit them directly.
- **Overlays**: Custom overlays are defined in `flake.nix` under `overlays = [...]`.
- **Dual Boot**: Orion has Windows dual boot; `scripts/reboot-to-windows.sh` uses `bootctl` to switch UEFI boot entry.
- **YubiKey**: Assumed for SSH (FIDO2) and GPG. See README.md for setup.
- **NFS**: `modules/nfs/fileshare.nix` configures shares for private NAS at fileshare.se.
