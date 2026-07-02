# home-modules/AGENTS.md

Home Manager modules. Three categories: pure config, option-based, and sandboxed agents.

## Structure

```
home-modules/
├── lib.nix          # Shared: readSkillsFrom (scans dirs for skill subdirs)
├── claude/          # Claude Code: wrapper, permissions, 6 MCP servers, skills → [AGENTS.md]
├── copilot-cli/     # Copilot CLI: fence sandbox (code template), Azure DevOps MCP
├── opencode/        # OpenCode: nono (Landlock) sandbox, oh-my-openagent config
├── fish/            # Fish shell: plugins, abbreviations, dev vs base variants
├── git/             # Git: 4 variants (personal/work × GPG/SSH signing)
├── gpg/             # GPG: hardened settings, key import by trust level
├── ssh/             # SSH: YubiKey FIDO2, 1Password agent, work variant
└── xorg/            # Xorg: allow-root systemd service
```

## Where to Look

- **Add AI agent config** → `claude/`, `copilot-cli/`, or `opencode/` — see agent patterns below
- **Add fish abbreviations** → `fish/default.nix` or `fish/dev.nix` — `programs.fish.shellAbbrs`
- **Change git identity** → `git/default.nix` (personal), `git/cab.nix` (work) — 4 variants total
- **Add GPG public keys** → `gpg/public-keys/<trust-level>/` — `personal/`, `fully-trusted/`, `marginally-trusted/`
- **Fix SSH config issues** → `ssh/default.nix` — post-activation hook copies Nix symlink to regular file
- **Add a shared skill** → `ai/skills/<name>/SKILL.md` — loaded via `readSkillsFrom`
- **Add Claude-only skill** → `claude/skills/<name>/SKILL.md` — Claude-specific

## Module Patterns

### Pure Config (no options)

Simple modules imported directly by hosts. No `options` block, just `config`. Examples: `fish/`, `git/`, `gpg/`, `ssh/`

### Option-Based (`modules.<name>`)

Modules defining `options.modules.<name>.{enable, preSetupScripts, runtimeInputs}`. Configured by host-level modules via
`home-manager.users.${username}`. Examples: `claude/`, `copilot-cli/`, `opencode/`

### Variant Pattern

Multiple files per concern, host picks one via import.

- `git/`: `default.nix` (GPG), `ssh.nix` (1Password SSH), `cab.nix` (work), `cab-ssh.nix` (work SSH)
- `ssh/`: `default.nix` (1Password agent), `cab.nix` (plain SSH)
- `fish/`: `default.nix` (base), `dev.nix` (adds Docker, GH_TOKEN from SOPS)

### Sandboxed Agents (copilot-cli, opencode)

**copilot-cli** uses `fence` (from `llm-agents` input) with the `code` template: network filtering via proxy, filesystem
restrictions, dangerous command blocking, secret protection. On WSL, fence auto-detects the environment and handles
`/init` interop.

**opencode** uses `nono` (Landlock + seccomp) with a default-deny egress allowlist
(`home-modules/opencode/nono-profile.jsonc` — see `nono-egress.md` for rationale). Pattern:

1. Define wrapper with `writeShellApplication`; `exec` the static launch script (`scripts/opencode-launch.sh`) which
   validates session dirs and invokes `nono run`
1. Sandbox policy lives in `nono-profile.jsonc`: filesystem grants, env var allowlist, `network.allow_domain` egress
   list, `open_port` for loopback IPC
1. Secrets injected read-only via SOPS env templates sourced through `preSetupScripts`
1. Skills loaded via `readSkillsFrom`

### Skill Loading

`lib.nix` provides `readSkillsFrom dir` — returns attrset of `{ name = "/path/to/dir/name"; }` for all subdirs. Agents
load from: `ai/skills/` (shared) + agent-specific dirs.

## Conventions

- Option namespace: `modules.<name>` (claude, copilot-cli, opencode) — NOT `programs.<name>`
- Wrapper scripts use `writeShellApplication` with `checkPhase = "true"` (skip shellcheck)
- SSH post-activation: `home.activation.fixSshConfig` replaces Nix store symlink (SSH rejects nobody-owned config)
- `home-manager.backupFileExtension = "hm-backup"` — conflicts create `.hm-backup` files

## Anti-Patterns

- **NEVER** create new HM module with `programs.<name>` options — use `modules.<name>`
- **NEVER** edit files in `gpg/public-keys/` that aren't `.asc` — binary keys will corrupt
- **NEVER** bypass sandbox for agent wrappers — security boundary
