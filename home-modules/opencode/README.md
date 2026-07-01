# OpenCode + Oh-My-OpenAgent (OMO)

[OpenCode](https://opencode.ai) wrapped in a [jail-nix](https://github.com/anomalyco/jail-nix) bubblewrap + seccomp
sandbox, plus the [Oh-My-OpenAgent](https://omo.dev) multi-agent orchestration plugin. Used by both
[orion](../../hosts/orion/) and [p51](../../hosts/p51/).

## Files

| File                                                             | Purpose                                                                        |
| ---------------------------------------------------------------- | ------------------------------------------------------------------------------ |
| [`default.nix`](./default.nix)                                   | Wrapper: env vars, runtime inputs, exports the launch-script inputs.           |
| [`oh-my-openagent.nix`](./oh-my-openagent.nix)                   | OMO config: agent/category → model mappings, plugins, TUI keybinds, team mode. |
| [`nono-profile.jsonc`](./nono-profile.jsonc)                     | nono sandbox policy: filesystem/env/network grants. Source of truth.           |
| [`nono-egress.md`](./nono-egress.md)                             | Egress allowlist analysis, SSH/webfetch tensions, TUI loopback + grants.       |
| [`nono-audit.md`](./nono-audit.md)                               | Audit trail: destination, append-only guarantee, rotation timer, reading.      |
| [`scripts/opencode-launch.sh`](../../scripts/opencode-launch.sh) | Static launch logic: runtime dirs, session-dir perms, token sync, `nono run`.  |
| [`README.md`](./README.md)                                       | This file.                                                                     |

## Provider stack

Four providers, three auth strategies. The model catalog and per-agent rationale live in
[`oh-my-openagent.nix`](./oh-my-openagent.nix); the billing/auth setup is documented here.

| Provider          | How it's wired                                      | Auth mechanism                                       | Used for                                                          |
| ----------------- | --------------------------------------------------- | ---------------------------------------------------- | ----------------------------------------------------------------- |
| `zai-coding-plan` | apiKey in `provider.*.options.apiKey` (host config) | SOPS env var `ZAI_API_KEY`                           | GLM-5.2 / 5.1 / 5-turbo / 5v-turbo (default orchestrator)         |
| `openai`          | apiKey in `provider.*.options.apiKey` (host config) | SOPS env var `OPENAI_API_KEY`                        | GPT-5.5 (Hephaestus only, plus last-resort fallbacks)             |
| `anthropic`       | Model IDs in OMO config (`anthropic/claude-*`)      | `@ex-machina/opencode-anthropic-auth` plugin (OAuth) | Claude Opus 4.8 / Sonnet 4.6 / Haiku 4.5 (Claude Code Max $90/mo) |
| `opencode-go`     | Model IDs in OMO config (`opencode-go/*`)           | `opencode auth login --provider opencode-go` (OAuth) | Kimi K2.7-code, Qwen 3.7-plus, MiniMax M3/M2.7 ($10/mo flat)      |

SOPS is only suitable for the two **API-key** providers (top two rows). OAuth-based providers store dynamically
refreshed tokens on disk; they cannot be SOPS-managed.

## First-time setup (once per machine)

```fish
# 1. SOPS-managed API keys (z.ai + OpenAI) — already wired by `nixos-rebuild switch`.
#    sops-nix materializes agents.env under /run/secrets/, then the opencode wrapper
#    sources it via preSetupScripts before launching the jail. The env vars are NOT
#    visible in your normal shell — they exist only inside the opencode process.

# 2. Claude Code Max (OAuth — reuses `claude` CLI session via the @ex-machina plugin):
claude auth login
#    Browser flow against claude.ai. Tokens land in ~/.claude/.credentials.json; the plugin
#    reads them and auto-refreshes. Requires Claude Pro/Max subscription (NOT Anthropic API credits).

# 3. OpenCode Go (OAuth):
opencode auth login --provider opencode-go
#    Browser flow against opencode.ai. Tokens land in ~/.local/share/opencode/.
```

`~/.claude/`, `~/.local/share/opencode/`, and `~/.local/share/opencode-anthropic-auth/` are all rw bind-mounted inside
the OpenCode jail (see `default.nix`), so the sandboxed OpenCode process can read and refresh tokens.

## Why the `@ex-machina/opencode-anthropic-auth` plugin

The plugin intercepts `anthropic/*` model requests, injects Claude Code Max OAuth headers, and auto-refreshes tokens.
This is the [ankarhem pattern](https://github.com/ankarhem/nix-config) — it reuses the existing `claude` CLI session
instead of requiring a separate OpenCode Zen subscription. Claude Max ($90/mo from claude.ai) is a separate product from
Anthropic API credits (pay-per-usage from platform.claude.com); the plugin uses the former.

The plugin is a **consumer** of OAuth tokens, not a producer. It reads from `~/.local/share/opencode/auth.json`. A small
sync script ([`scripts/opencode-anthropic-auth-sync.sh`](../../scripts/opencode-anthropic-auth-sync.sh)), wired into the
jail's `add-runtime`, copies tokens from `~/.claude/.credentials.json` (populated by `claude auth login`) into
`auth.json` on every OpenCode startup. Idempotent — skips cleanly when source tokens are missing or already up to date.

Notes:

- Claude Code (the separate `claude` CLI) prefers the `ANTHROPIC_AUTH_TOKEN` env var over the OAuth tokens, so it keeps
  using z.ai GLM (per the `claude.env` SOPS template). This is intentional. Claude Code's "auth source conflict" warning
  is informational and can be ignored.

## Agent model design

Per OMO docs (`agent-model-matching.md`) with two user-chosen deviations:

1. **GLM-5.2 is the orchestrator default** (sisyphus / prometheus / atlas). Docs recommend Claude Opus 4.8; user prefers
   GLM-5.2 as a Claude Opus alternative. Anthropic remains the first fallback layer.
1. **OpenAI is pay-per-usage and used sparingly** — only Hephaestus (which has no fallback chain) and a few last-resort
   fallback entries. Everything the docs default to OpenAI uses real Anthropic (Claude Opus 4.8 / Sonnet 4.6) instead.

| Tier              | Primary                           | First fallback                | Second fallback              |
| ----------------- | --------------------------------- | ----------------------------- | ---------------------------- |
| Orchestrators     | `glm-5.2`                         | `anthropic/claude-opus-4-8`   | `opencode-go/kimi-k2.7-code` |
| Deep / review     | `anthropic/claude-opus-4-8` (max) | `opencode-go/kimi-k2.7-code`  | `openai/gpt-5.5`             |
| Visual / artistry | `opencode-go/qwen3.7-plus`        | `anthropic/claude-opus-4-8`   | `kimi-k2.7-code`             |
| Utility           | `opencode-go/kimi-k2.7-code`      | `opencode-go/qwen3.7-plus`    | `opencode-go/minimax-m2.7`   |
| Hephaestus        | `openai/gpt-5.5`                  | — (single-entry, no fallback) |                              |

The full agent-by-agent and category-by-category matrix is the source of truth in
[`oh-my-openagent.nix`](./oh-my-openagent.nix); this table is the executive summary.

## Background-task parallelism

`background_task.providerConcurrency` in the OMO config caps how many concurrent requests each provider will accept from
background subagents. Tuned to match provider economics:

| Provider          | Cap | Reason                                                     |
| ----------------- | --- | ---------------------------------------------------------- |
| `openai`          | 3   | Pay-per-usage — bound the spend rate.                      |
| `anthropic`       | 3   | Claude Code Max — tighter rate limits on the subscription. |
| `opencode-go`     | 5   | $10/mo shared sub — fair-use limits, not unlimited.        |
| `zai-coding-plan` | 5   | Coding Plan — moderate.                                    |

## Team Mode

Enabled (`team_mode.enabled = true`) with safe defaults: 4 in flight, 8 max members, no tmux visualization. This unlocks
12 `team_*` tools for parallel multi-agent coordination. See [OMO Team Mode docs](https://omo.dev/docs#team-mode) for
usage.

## nono session dir permissions

nono refuses to start unless its session state dir (`~/.nono/sessions`) is private (mode `700`), failing with:

```
nono: Configuration parse error: /home/<user>/.nono/sessions must not be group/world accessible; chmod 700 and retry
```

With the default `umask` (`022`), nono auto-creates `~/.nono/sessions` as `755` (group/world-readable), which trips this
check. The [`opencode-launch.sh`](../../scripts/opencode-launch.sh) script therefore pre-creates the dir and locks down
the perms before launching nono, regardless of the active umask:

```sh
mkdir -p "$HOME/.nono/sessions"
chmod 700 "$HOME/.nono" "$HOME/.nono/sessions"
```

This also self-heals a dir left at the wrong mode by an earlier failed run — the `chmod` corrects it on the next launch,
so no manual cleanup is needed.

## Launch script

The static launch logic lives in [`scripts/opencode-launch.sh`](../../scripts/opencode-launch.sh), kept out of the Nix
wrapper so it stays readable and shellcheckable. [`default.nix`](./default.nix) only assembles the dynamic inputs
(config JSON, profile path, opencode binary, persistent dirs) and exports them as `OC_*` env vars before `exec`-ing the
script. The script then ensures opencode's runtime dirs exist, locks down the nono session dir (above), syncs Claude Max
OAuth tokens, pins the TUI loopback `--port`, and execs `nono run` with the profile. See the script header for the full
input contract.

## Disabled runtime-skills

OMO's bundled `security-research` / `security-review` skills are served from a runtime localhost HTTP server that binds
a **dynamic** port (`bun.serve port:0`). nono on Linux only allows explicit `open_port` entries (`port:0` is
macOS-only), so the bind is blocked and OMO logs a benign-but-noisy `[runtime-skills] … permission denied 127.0.0.1:0`
overlay at startup. Listing both in `disabled_skills` (in [`oh-my-openagent.nix`](./oh-my-openagent.nix)) makes
`selectRuntimeSecuritySkills()` return `[]`, so the server is never created and the warning never fires. The skills
require team mode and spawn 5 subagents, so they have limited use inside the sandbox anyway.

## Clipboard

OpenCode runs inside the nono sandbox, which by default has no access to the host's Wayland compositor. That broke
copy/paste: OpenCode showed a "copied to clipboard" toast, but the bytes never reached the system clipboard
([upstream issue anomalyco/opencode#13984](https://github.com/anomalyco/opencode/issues/13984)). Two independent knobs
address this.

### `OPENCODE_EXPERIMENTAL_DISABLE_COPY_ON_SELECT=true` (always set)

Exported by the wrapper in [`default.nix`](./default.nix) and allowlisted in
[`nono-profile.jsonc`](./nono-profile.jsonc) (`environment.allow_vars`) so it survives into the sandboxed process. It
disables OpenCode's auto-copy-on-select so a mouse drag falls through to GNOME Terminal's native selection handler. This
keeps terminal-native copy/paste working — **Shift+drag** to select, **Ctrl+Shift+C** to copy, **Ctrl+Shift+V** to paste
— for users who want to position the terminal cursor without triggering a copy.

### `modules.opencode.enableWaylandClipboard` (per-host, default `false`)

Enabled on the Wayland desktop hosts (orion, p51); left `false` on non-graphical hosts (wsl-cab, iso, hl-jump). When
enabled it does two things:

1. Adds `wl-clipboard` to the sandbox PATH so OpenCode's explicit copy actions (the copy button on messages, Ctrl+C in
   the TUI, and auto-copy-on-select when the env var above is unset) can shell out to `wl-copy`.
1. Exports `OC_WAYLAND_CLIPBOARD=1` to [`opencode-launch.sh`](../../scripts/opencode-launch.sh), which passes
   `nono run --allow-unix-socket "$XDG_RUNTIME_DIR/$WAYLAND_DISPLAY"` to grant `connect()` to the compositor socket.
   `WAYLAND_DISPLAY` / `XDG_RUNTIME_DIR` are allowlisted in the profile so `wl-copy` can locate the socket inside the
   sandbox.

The launch script guards the grant with a runtime existence check on the socket, so OpenCode still launches cleanly from
a TTY, SSH, or X11 session — it just runs without clipboard access there.

**Why `--allow-unix-socket` and not a profile filesystem grant:** the Wayland socket path is session-dependent
(`$XDG_RUNTIME_DIR/$WAYLAND_DISPLAY`), so it cannot be baked into the static profile. The launch script resolves it at
runtime and passes the single-socket grant only when the host opts in and the socket exists.

**Security:** this grants `connect()`-only access to a single AF_UNIX socket — not a directory, not a compositor
filesystem tree. No X11, GPU, or network surface is added. This is the same clipboard permission surface flatpaks use.

## See also

- [OMO Agent-Model Matching Guide](https://omo.dev/docs#agent-model-matching) — full fallback chains per agent.
- [OpenCode provider docs](https://opencode.ai/docs/providers/) — provider configuration reference.
