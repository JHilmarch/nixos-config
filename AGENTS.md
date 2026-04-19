# AGENTS.md

This file provides guidance to AI agents when working with code in this repository. Applies to: Claude Code, OpenCode
(oh-my-openagent), GitHub Copilot CLI.

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
home-modules/       # Home Manager modules (claude, copilot-cli, fish, git, gpg, ssh, xorg)
packages/           # Custom packages exposed as pkgs.local.<name>
templates/          # Host templates (common, desktop, server, proxmox-lxc)
users/              # User definitions (jonatan)
functions/          # Shared helper functions (GitHub SSH key fetcher)
tools/              # Fish scripts (update-packages, gh-project-manager)
scripts/            # Shell scripts (reboot-to-windows.sh)
secrets/            # SOPS-encrypted secrets (never read or edit)
ai/skills/          # Shared skills for AI agents (claude, copilot-cli, opencode)
```

## Flake Architecture

Four nixosConfigurations in flake.nix. Each host receives specialArgs: inputs, self, username, hostname. Orion
additionally receives pkgs-unstable, functions. hl-jump receives functions.

Key inputs: nixpkgs (25.11), nixpkgs-unstable, home-manager, sops-nix, nixos-wsl, nix-index-database, NUR, llm-agents.

Home Manager integrated per-host with extraSpecialArgs. Custom packages in packages/ exposed via overlay as
pkgs.local.<name>.

## Behavioral Rules

### MCP Integration

- **nixos**: Always use proactively for Nix package/option/program searches.
- **context7**: Use for library/API docs, but ask first.
- **github-personal**: Default for all personal GitHub operations.
- **github-work**: Only when explicitly told something is work-related.

### Terminal & Conventions

- Provide commands for fish shell.

### Skill Usage

Project-level skills in `.claude/skills/` are available to all agents. Shared skills live in `ai/skills/` and are loaded
declaratively by Nix. Agent-specific skills remain in `home-modules/<agent>/skills/`.

- **commit**: Always invoke `/commit` when creating git commits. Never run `git commit` directly.
- **ck**: Prefer `/ck` over Grep/Glob/find for codebase searches.
- **update-packages**: Use `/update-packages` for updating flake inputs.
- **using-git-worktrees**: Always invoke `/using-git-worktrees` before starting implementation work. Never edit main
  directly for scoped tasks.
- **project-manager**: Use `/project-manager` when managing GitHub Project boards, user stories, or task assignments.

## Domain Knowledge

- **Secrets**: All files in secrets/ are SOPS-encrypted with age. Never read or edit.
- **Dual Boot**: Orion has Windows dual boot; scripts/reboot-to-windows.sh uses bootctl to set the next UEFI boot entry.
- **YubiKey**: Used for SSH (FIDO2) and GPG. See README.md for setup.
- **NFS**: modules/nfs/fileshare.nix configures shares for private NAS at fileshare.se.
- **Claude Code** (Claude): Configured via home-modules/claude/ with wrapper scripts.
- **Copilot CLI** (Copilot): Configured via home-modules/copilot-cli/ with jail sandbox.
