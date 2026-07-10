# AGENTS.md

**Commit:** cdb3b52 **Branch:** main

NixOS flake-based configuration. Five hosts, custom packages, AI agent sandboxing. Applies to: Claude Code, OpenCode,
GitHub Copilot CLI.

## Structure

```
hosts/              # Per-host configuration.nix + home.nix
├── orion/          # Desktop (GNOME, NVIDIA, LUKS+FIDO2, YubiKey, dual boot) → [AGENTS.md]
├── p51/            # Laptop (GNOME, LUKS+FIDO2, YubiKey USB/IP)
├── wsl-cab/        # WSL dev env (work identity, Copilot CLI, Azure DevOps)
├── iso/            # Minimal installation ISO (no Home Manager)
├── edge/           # Proxmox LXC ingress/reverse-proxy (nginx, static IP)
└── cache/          # Proxmox LXC binary cache (nix-serve-ng behind nginx TLS)
tofu/               # OpenTofu homelab provisioning (Proxmox LXCs) → [README.md]
modules/            # System-level NixOS modules → [AGENTS.md]
home-modules/       # Home Manager modules → [AGENTS.md]
packages/           # Custom packages (pkgs.local.*) → [AGENTS.md]
templates/          # Composable host bases (common→desktop/server→proxmox-lxc)
users/              # User definitions (jonatan)
functions/          # Build-time helpers (GitHub SSH key fetcher, NuGet builder)
tools/              # Fish CLI scripts (update-packages, gh-project-manager)
scripts/            # Shell scripts (reboot-to-windows.sh, secrets-sops.sh, yubikey-usbip/*)
hooks/              # Git hooks (commit-msg conventional commits enforcer)
secrets/            # SOPS-encrypted secrets (NEVER read or edit)
ai/skills/          # Shared AI agent skills (SKILL.md per directory)
```

## Where to Look

- **Add a system-level feature** → `modules/` — use `mkEnableOption` pattern, see AGENTS.md there
- **Add a home-manager feature** → `home-modules/` — see AGENTS.md for jail/skill patterns
- **Add/update a custom package** → `packages/` — exposed as `pkgs.local.<name>`, see AGENTS.md
- **Configure a specific host** → `hosts/<name>/` — Orion has its own AGENTS.md
- **Add a shared AI skill** → `ai/skills/<name>/SKILL.md` — auto-discovered by `readSkillsFrom` (user-scope: loaded in
  every project)
- **Add a project-scope AI skill** → `.claude/skills/<name>/SKILL.md` — scanned natively by opencode + Claude Code
  (loaded only inside this repo; use for skills that only make sense here, e.g. `verify-flake`)
- **Add a Claude-specific skill** → `home-modules/claude/skills/<name>/SKILL.md` — Claude-only
- **Update a package version** → `tools/update-packages/` — Fish CLI, per-package .fish files
- **Add a new user** → `users/<name>.nix` — register in `users/default.nix` attrset
- **Add a new host** → `hosts/<name>/` — add nixosConfiguration in flake.nix
- **Provision a homelab LXC** → `tofu/` — OpenTofu creates/sizes Proxmox containers; see `tofu/README.md` for bootstrap,
  destroy/recreate, and clean-checkout recovery
- **Change formatting rules** → `treefmt.nix` — alejandra, mdformat, fish_indent, biome
- **Manage GitHub Projects** → `tools/gh-project-manager/` — Fish CLI with --json output

## Flake Architecture

**Inputs (11):** nixpkgs (25.11), nixpkgs-unstable, home-manager (25.11), sops-nix, nixos-wsl, nix-index-database, NUR,
mcp-nixos, llm-agents, treefmt-nix, vscode-server. All follow nixpkgs except llm-agents→treefmt-nix.

**specialArgs matrix:**

- **orion**: inputs/self ✓, username jonatan, hostname nixos-orion, pkgs-unstable ✓, functions ✓, local overlay ✓
- **p51**: inputs/self ✓, username jonatan, hostname nixos-p51, pkgs-unstable ✓, functions ✓, local overlay ✓
- **wsl-cab**: inputs/self ✓, username jonatan, hostname wsl-cab, pkgs-unstable ✗, functions ✗, local overlay ✓
- **iso**: inputs/self ✓, username jonatan, hostname iso, pkgs-unstable ✗, functions ✗, local overlay ✗
- **edge**: inputs/self ✓, username jonatan, hostname edge, pkgs-unstable ✗, functions ✓, local overlay ✗

**Template chain:** `desktop.nix`→`common.nix`→`defaults.nix`;
`proxmox-lxc.nix`→`server.nix`→`common.nix`→`defaults.nix`

## Conventions

- **Formatting:** `nix fmt` (alejandra for Nix, mdformat with `mdformat-frontmatter` + `mdformat-gfm` plugins for MD,
  fish_indent for Fish, biome for JS/TS/JSON/CSS/HTML)
- **Indentation:** 2 spaces. Line length: 100 (Nix), 120 (everything else). LF endings.
- **Formatting excludes:** `secrets/*`, `*.age` (skill `SKILL.md` YAML frontmatter is preserved by
  `mdformat-frontmatter`; no exclude needed)
- **Hooks auto-format on Edit/Write:** .nix→alejandra, .fish→fish_indent, .md→mdformat, .json→biome
- **Nix naming:** kebab-case files/dirs, camelCase options (`systemdNoSleep`), camelCase variables
- **Fish naming:** `cmd_<name>` dispatch, `SCREAMING_SNAKE_CASE` globals, `snake_case` locals
- **Imports:** `"${self}/path"` for shared, `"./path"` for local
- **HM integration:** NixOS module pattern (not standalone). `extraSpecialArgs = specialArgs` mirrors all system args.
- **Shell commands:** Always provide for fish.
- **Searching code:** The opencode jail lacks GNU `grep`; use **`ck` (preferred)** or `rg` for shell-based code search.
  The built-in Grep tool wraps `rg` and is always safe. Bare `grep` from a shell fails (`grep: command not found`) and
  wastes a round-trip.

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
- **NEVER** call bare `grep` from agent shells — the opencode jail lacks GNU grep; use `ck` (preferred) or `rg`
- **NEVER** use `git merge --no-ff` — always rebase feature branches onto current main first, then merge with
  `--ff-only` for linear history (see `/using-git-worktrees` "Merge-back to main")
- **ALWAYS** use nixos MCP proactively for package/option searches
- **ALWAYS** use `--json` flag with ck, update-packages, project-manager tools
- **ALWAYS** format after editing Nix files (hooks do this automatically)
- **ALWAYS** wait for user approval before creating GitHub issues
- **Conventional Commits enforced** by hooks/commit-msg (50-char subject, 72-char body)

## Comments & Documentation

- **Avoid inline comments.** Prefer refactoring into a well-named method/function over explaining code. Write an inline
  comment ONLY when you can't refactor for readability, or to explain why a convention is broken. Keep it to 1 line.
- **File/module/function docs** go in a short doc section above the function or at the top of the file/module — not
  scattered inline.
- **Longer explanations** (how a subsystem works, guidelines, troubleshooting) go in a `README`, focused on how it works
  **right now**. No architecture-decision logs, logbooks, plan references, or "how it used to / will work".
- **NEVER reference issue/PR numbers** in comments or docs. Only exception: a `TODO` comment pointing at an open bug.

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
- **YubiKey:** SSH (FIDO2), GPG, LUKS unlock via initrd scripts in `hosts/orion/boot-initrd-scripts/`. USB/IP forwarding
  (`services.yubikeyUsbip`) is enabled on both orion and p51.
- **NFS:** `modules/nfs/fileshare.nix` for private NAS at fileshare.se.
- **AI Agent Sandboxing:** Copilot CLI uses fence (`code` template, from `llm-agents` input). OpenCode uses nono
  (Landlock + seccomp, default-deny egress allowlist — see `home-modules/opencode/`). Claude uses wrapper scripts.
- **Skill Loading:** `home-modules/lib.nix` provides `readSkillsFrom` — scans directories for skill subdirs.
- **SSH Config Workaround:** `home-modules/ssh/` copies Nix store symlink to regular file (SSH rejects nobody-owned
  config).
- **GitHub MCP:** Personal/work split via base/variant pattern reading PATs from `/run/secrets/`.
- **Azure DevOps:** Commits are NOT signed (work policy). wsl-cab uses work git identity.
- **Linear History:** `merge.ff = only` is set declaratively in every `home-modules/git/*.nix` variant, so every clone
  on every host refuses non-fast-forward merges at the git level. **Enforcement boundary:** the default `git merge`
  refuses with `fatal: Not possible to fast-forward, aborting.` when branches diverge — but an explicit
  `git merge --no-ff` flag still overrides this config (verified on git 2.54). The agent-facing rule in Anti-Patterns
  (`NEVER git merge --no-ff`) is the primary enforcement; `merge.ff=only` is the technical backstop for accidental
  non-ff merges. To merge a feature branch: rebase onto target first, then `git merge --ff-only <branch>` (see
  `/using-git-worktrees` skill's "Merge-back to main" section).
