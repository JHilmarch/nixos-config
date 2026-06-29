# OpenCode + Oh-My-OpenAgent (OMO)

[OpenCode](https://opencode.ai) wrapped in a [jail-nix](https://github.com/anomalyco/jail-nix) bubblewrap + seccomp
sandbox, plus the [Oh-My-OpenAgent](https://omo.dev) multi-agent orchestration plugin. Used by both
[orion](../../hosts/orion/) and [p51](../../hosts/p51/).

## Files

| File                                           | Purpose                                                                        |
| ---------------------------------------------- | ------------------------------------------------------------------------------ |
| [`default.nix`](./default.nix)                 | Jail wrapper: filesystem binds, env vars, secret injection, runtime inputs.    |
| [`oh-my-openagent.nix`](./oh-my-openagent.nix) | OMO config: agent/category → model mappings, plugins, TUI keybinds, team mode. |
| [`README.md`](./README.md)                     | This file.                                                                     |

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
check. The [`default.nix`](./default.nix) wrapper therefore pre-creates the dir and locks down the perms before
launching nono, regardless of the active umask:

```sh
mkdir -p "$HOME/.nono/sessions"
chmod 700 "$HOME/.nono" "$HOME/.nono/sessions"
```

This also self-heals a dir left at the wrong mode by an earlier failed run — the `chmod` corrects it on the next launch,
so no manual cleanup is needed.

## See also

- [OMO Agent-Model Matching Guide](https://omo.dev/docs#agent-model-matching) — full fallback chains per agent.
- [OpenCode provider docs](https://opencode.ai/docs/providers/) — provider configuration reference.
