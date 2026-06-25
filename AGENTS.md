# AGENTS.md

**Commit:** cdb3b52 **Branch:** main

NixOS flake-based configuration. Four hosts, custom packages, AI agent sandboxing. Applies to: Claude Code, OpenCode,
GitHub Copilot CLI.

## Structure

```
hosts/              # Per-host configuration.nix + home.nix
├── orion/          # Desktop (GNOME, NVIDIA, LUKS+FIDO2, YubiKey, dual boot) → [AGENTS.md]
├── wsl-cab/        # WSL dev env (work identity, Copilot CLI, Azure DevOps)
├── iso/            # Minimal installation ISO (no Home Manager)
└── hl-jump/        # Proxmox LXC jump host (nginx, static IP)
modules/            # System-level NixOS modules → [AGENTS.md]
home-modules/       # Home Manager modules → [AGENTS.md]
packages/           # Custom packages (pkgs.local.*) → [AGENTS.md]
templates/          # Composable host bases (common→desktop/server→proxmox-lxc)
users/              # User definitions (jonatan)
functions/          # Build-time helpers (GitHub SSH key fetcher, NuGet builder)
tools/              # Fish CLI scripts (update-packages, gh-project-manager)
scripts/            # Shell scripts (reboot-to-windows.sh, secrets-sops.sh)
hooks/              # Git hooks (commit-msg conventional commits enforcer)
secrets/            # SOPS-encrypted secrets (NEVER read or edit)
ai/skills/          # Shared AI agent skills (SKILL.md per directory)
```

## Where to Look

- **Add a system-level feature** → `modules/` — use `mkEnableOption` pattern, see AGENTS.md there
- **Add a home-manager feature** → `home-modules/` — see AGENTS.md for jail/skill patterns
- **Add/update a custom package** → `packages/` — exposed as `pkgs.local.<name>`, see AGENTS.md
- **Configure a specific host** → `hosts/<name>/` — Orion has its own AGENTS.md
- **Add a shared AI skill** → `ai/skills/<name>/SKILL.md` — auto-discovered by `readSkillsFrom`
- **Add a Claude-specific skill** → `home-modules/claude/skills/<name>/SKILL.md` — Claude-only
- **Update a package version** → `tools/update-packages/` — Fish CLI, per-package .fish files
- **Add a new user** → `users/<name>.nix` — register in `users/default.nix` attrset
- **Add a new host** → `hosts/<name>/` — add nixosConfiguration in flake.nix
- **Change formatting rules** → `treefmt.nix` — alejandra, mdformat, fish_indent, biome
- **Manage GitHub Projects** → `tools/gh-project-manager/` — Fish CLI with --json output

## Flake Architecture

**Inputs (12):** nixpkgs (25.11), nixpkgs-unstable, home-manager (25.11), sops-nix, nixos-wsl, nix-index-database, NUR,
mcp-nixos, llm-agents, jail-nix, treefmt-nix, vscode-server. All follow nixpkgs except llm-agents→treefmt-nix.

**specialArgs matrix:**

- **orion**: inputs/self ✓, username jonatan, hostname nixos-orion, pkgs-unstable ✓, functions ✓, local overlay ✓
- **wsl-cab**: inputs/self ✓, username jonatan, hostname wsl-cab, pkgs-unstable ✗, functions ✗, local overlay ✓
- **iso**: inputs/self ✓, username jonatan, hostname iso, pkgs-unstable ✗, functions ✗, local overlay ✗
- **hl-jump**: inputs/self ✓, username jonatan, hostname hl-jump, pkgs-unstable ✗, functions ✓, local overlay ✗

**Template chain:** `desktop.nix`→`common.nix`→`defaults.nix`;
`proxmox-lxc.nix`→`server.nix`→`common.nix`→`defaults.nix`

## Conventions

- **Formatting:** `nix fmt` (alejandra for Nix, mdformat for MD, fish_indent for Fish, biome for JS/TS/JSON/CSS/HTML)
- **Indentation:** 2 spaces. Line length: 100 (Nix), 120 (everything else). LF endings.
- **Formatting excludes:** `secrets/*`, `*.age`, `ai/skills/*`
- **Hooks auto-format on Edit/Write:** .nix→alejandra, .fish→fish_indent, .md→mdformat, .json→biome
- **Nix naming:** kebab-case files/dirs, camelCase options (`systemdNoSleep`), camelCase variables
- **Fish naming:** `cmd_<name>` dispatch, `SCREAMING_SNAKE_CASE` globals, `snake_case` locals
- **Imports:** `"${self}/path"` for shared, `"./path"` for local
- **HM integration:** NixOS module pattern (not standalone). `extraSpecialArgs = specialArgs` mirrors all system args.
- **Shell commands:** Always provide for fish.

## Anti-Patterns

- **NEVER** read or edit `secrets/` — SOPS-encrypted with age
- **NEVER** read or edit `.sops.yaml` — controls encryption keys, AI must ignore
- **NEVER** run `git commit` directly — always use `/commit` skill
- **NEVER** edit main directly — use `/using-git-worktrees` for scoped tasks
- **NEVER** commit secrets (.env, credentials, private keys, .pem, .key, .age)
- **NEVER** use bare `gh` — always use `gh-personal` or `gh-work` wrappers
- **NEVER** hardcode tokens — pass via SOPS env or secrets manager
- **NEVER** attempt to encrypt/decrypt secrets without user interaction — requires YubiKey presence
- **NEVER** use `as any`, `@ts-ignore` in any code
- **NEVER** amend commits unless explicitly asked
- **NEVER** use one `-m` per sentence in commit messages
- **ALWAYS** use nixos MCP proactively for package/option searches
- **ALWAYS** use `--json` flag with ck, update-packages, project-manager tools
- **ALWAYS** format after editing Nix files (hooks do this automatically)
- **ALWAYS** wait for user approval before creating GitHub issues
- **Conventional Commits enforced** by hooks/commit-msg (50-char subject, 72-char body)

## Commands

```fish
# Build and switch a host
sudo nixos-rebuild switch --flake .#nixos-orion

# Format all code
nix fmt

# Check formatting
nix flake check

# Update flake inputs
/update-packages  # or tools/update-packages/update-packages.fish
```

## Domain Knowledge

- **Secrets:** SOPS-encrypted with age. Decrypted by sops-nix to /nix/store. Agent wrappers source via
  `scripts/secrets-sops.sh`.
- **Dual Boot:** Orion has Windows dual boot; `scripts/reboot-to-windows.sh` uses bootctl to set next UEFI entry.
- **YubiKey:** SSH (FIDO2), GPG, LUKS unlock via initrd scripts in `hosts/orion/boot-initrd-scripts/`.
- **NFS:** `modules/nfs/fileshare.nix` for private NAS at fileshare.se.
- **AI Agent Sandboxing:** Copilot CLI uses fence (`code` template, from `llm-agents` input). OpenCode uses jail-nix
  (bubblewrap + seccomp). Claude uses wrapper scripts.
- **Skill Loading:** `home-modules/lib.nix` provides `readSkillsFrom` — scans directories for skill subdirs.
- **SSH Config Workaround:** `home-modules/ssh/` copies Nix store symlink to regular file (SSH rejects nobody-owned
  config).
- **GitHub MCP:** Personal/work split via base/variant pattern reading PATs from `/run/secrets/`.
- **Azure DevOps:** Commits are NOT signed (work policy). wsl-cab uses work git identity.
