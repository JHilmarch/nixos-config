# OpenCode + Oh-My-OpenAgent (OMO)

[OpenCode](https://opencode.ai) wrapped in a [nono](https://github.com/anomalyco/nono) Landlock + seccomp sandbox
(default-deny egress allowlist), plus the [Oh-My-OpenAgent](https://omo.dev) multi-agent orchestration plugin. Used by
both [orion](../../hosts/orion/) and [p51](../../hosts/p51/).

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

| Provider          | How it's wired                                      | Auth mechanism                                       | Used for                                                                   |
| ----------------- | --------------------------------------------------- | ---------------------------------------------------- | -------------------------------------------------------------------------- |
| `zai-coding-plan` | apiKey in `provider.*.options.apiKey` (host config) | SOPS env var `ZAI_API_KEY`                           | GLM-5.2 / 5.1 / 5-turbo / 5v-turbo (first non-Anthropic fallback layer)    |
| `openai`          | apiKey in `provider.*.options.apiKey` (host config) | SOPS env var `OPENAI_API_KEY`                        | GPT-5.5 (Hephaestus only, plus last-resort fallbacks)                      |
| `anthropic`       | Model IDs in OMO config (`anthropic/claude-*`)      | `@ex-machina/opencode-anthropic-auth` plugin (OAuth) | Fable 5 / Opus 4.8 / Sonnet 5 / Haiku 4.5 (Claude Code Max $90/mo)         |
| `opencode-go`     | Model IDs in OMO config (`opencode-go/*`)           | `opencode auth login --provider opencode-go` (OAuth) | Kimi K2.7-code, Qwen 3.7-plus, MiniMax M3/M2.7, DeepSeek V4 Flash ($10/mo) |

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

Two providers carry the premium tiers — Anthropic (Claude) and z.ai (GLM) — and their relative order is a **per-host
choice** (see [Per-host model options](#per-host-model-options)). The remaining rules are user-chosen deviations from
the OMO docs (`agent-model-matching.md`):

1. **Fable 5 is an opt-in premium primary through 2026-07-07** (included for up to 50% of Claude Max weekly limits),
   with Opus 4.8 as the next Claude-layer entry. Gated by the per-host `modules.opencode.useFable` option (default
   `false`; `true` on p51). Usage credits are disabled, so an exhausted Fable surfaces as HTTP 402 and the runtime
   fallback (below) degrades to Opus within seconds. **Sisyphus never leads with Fable** — as the highest-volume premium
   agent it is too expensive to run on Fable, so it always starts at Opus 4.8 (or GLM, per preference) regardless of
   `useFable`.
1. **Provider preference is a per-host switch** (`modules.opencode.modelPreference`: `anthropic` / `zai` / `balanced`,
   default `anthropic`). It reorders the Claude-layer vs the GLM-layer inside every premium chain. This supersedes the
   old hardcoded "GLM before Kimi" deviation — the Claude↔GLM order is now explicit and host-tunable. See
   [Per-host model options](#per-host-model-options) for the exact per-mode behavior.
1. **OpenAI is pay-per-usage and used sparingly** — only Hephaestus (which has no fallback chain) and a few last-resort
   fallback entries. OpenCode Go and OpenAI models are always last resort in premium chains, after both Claude and GLM.
1. **Utility tier primary follows the host preference for librarian** — when `modelPreference` is `anthropic` or
   `balanced`, Haiku 4.5 leads and DeepSeek V4 Flash is the first fallback (Claude Max budget permitting). Under `zai`,
   librarian stays on DeepSeek V4 Flash as primary to preserve the OpenCode Go budget, with Haiku as the first fallback.
   Explore is unaffected — it always leads with MiniMax M2.7 (fastest latency for grep-style bursts), Haiku as fallback.
   The workload split still follows the docs' "DeepSeek ≻≻ MiniMax" rule — MiniMax only on grep-style utility, never on
   deep/multi-step agents.
1. **Visual fallbacks stay inside the Qwen family** — per the docs' "Safe vs Dangerous Overrides": visual-engineering →
   Kimi/GLM is a wrong-reasoning-style override; Qwen substitutes for Gemini (no Google provider is connected, so Qwen
   3.7-plus is the *primary*, Qwen 3.6-plus the fallback, GPT-5.5 the only non-Qwen tail).

Executive summary (shown for `modelPreference = "anthropic"`, `useFable = true`; the Claude/GLM columns swap under
`zai`, and alternate per agent under `balanced`). The librarian row also swaps under `zai` — DeepSeek becomes the
primary and Haiku the first fallback:

| Tier              | Primary                          | Next (Claude layer)               | Then (GLM layer) | Tail               |
| ----------------- | -------------------------------- | --------------------------------- | ---------------- | ------------------ |
| Sisyphus          | `anthropic/claude-opus-4-8`      | — (no Fable)                      | `glm-5.2`        | `kimi`             |
| Orchestrators     | `anthropic/claude-fable-5`       | `anthropic/claude-opus-4-8`       | `glm-5.2`        | `kimi` / `gpt-5.5` |
| Deep / review     | `anthropic/claude-fable-5` (max) | `anthropic/claude-opus-4-8` (max) | `glm-5.2`        | `kimi` → `gpt-5.5` |
| Workers (junior)  | `anthropic/claude-sonnet-5`      | `kimi` (Claude-like)              | `glm-5.2`        | `minimax-m3`       |
| Visual / artistry | `opencode-go/qwen3.7-plus`       | `opencode-go/qwen3.6-plus`        | —                | `gpt-5.5`          |
| Librarian         | `anthropic/claude-haiku-4-5`     | `opencode-go/deepseek-v4-flash`   | `glm-5-turbo`    |                    |
| Explore           | `opencode-go/minimax-m2.7`       | `anthropic/claude-haiku-4-5`      | `glm-5-turbo`    |                    |
| Hephaestus        | `openai/gpt-5.5`                 | — (single-entry, no fallback)     |                  |                    |

The full agent-by-agent and category-by-category matrix is the source of truth in
[`oh-my-openagent.nix`](./oh-my-openagent.nix); this table is the executive summary.

## Per-host model options

Two options on `modules.opencode` (declared in [`default.nix`](./default.nix), consumed in
[`oh-my-openagent.nix`](./oh-my-openagent.nix)) let each host tune the premium chains without editing the shared module.
Set them in `hosts/<host>/modules/opencode.nix`.

### `useFable` (bool, default `false`)

Enables Claude Fable 5 as the premium primary for the deep/review and orchestrator/planner chains — **except sisyphus**,
which never leads with Fable. Currently `true` on p51 only. Flip a host to `false` (or let the default stand) and Opus
4.8 becomes that host's Claude-layer primary everywhere. After 2026-07-07 (promo ends → Fable bills via disabled credits
→ 402), set every host to `false`.

### `modelPreference` (enum, default `"anthropic"`)

Reorders the Claude-layer vs GLM-layer inside each premium chain. OpenCode Go / OpenAI tails are unaffected — always
last.

| Mode        | Behavior                                                                                                                                                                                                                  |
| ----------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `anthropic` | Claude models before GLM in every premium chain. Junior/Atlas fall back Kimi (Claude-like) before GLM.                                                                                                                    |
| `zai`       | GLM before Claude — spend the z.ai Coding Plan token budget first; Anthropic is the next layer.                                                                                                                           |
| `balanced`  | Alternate the preferred provider agent-by-agent (via a per-agent `slot` index) so compute is spread across both subscriptions instead of hammering one. Even-slot agents lead with Claude, odd-slot agents lead with GLM. |

Implementation: the `premium` / `sonnetChain` helpers in [`oh-my-openagent.nix`](./oh-my-openagent.nix) build each chain
from a reorderable Claude layer + GLM layer + a fixed tail; `claudeBeforeGlm slot` decides the order. Verify a host's
effective chains with:

```fish
nix eval --raw '.#nixosConfigurations.nixos-p51.config.home-manager.users.jonatan.home.file.".config/opencode/oh-my-openagent.json".text' | jq '.agents'
```

## Runtime fallback

OMO's `runtime_fallback` hook is **enabled** (it is OFF by default upstream — without it the `fallback_models` chains
only apply at session start, and a mid-session 429/402 just loops upstream OpenCode's hardcoded exponential backoff,
observed as ~8 retries of 2s→30s). Two failover paths, verified against OMO source
(`packages/omo-opencode/src/hooks/runtime-fallback/`):

- **Non-retryable errors (402):** upstream doesn't retry → `session.error` → OMO checks `retry_on_errors` → immediate
  fallback. 402 is added to the list because usage credits are disabled.
- **Retryable errors (429/503/529):** upstream starts its backoff loop and emits a retry status → OMO's session-status
  handler intercepts the **first** matching signal (message-pattern match, independent of `retry_on_errors`), aborts,
  and switches. Per-code retry counts ("give 503 a few retries first") are **not expressible** in current OMO — fast
  failover for everything is the accepted trade-off.

Config choices (in [`oh-my-openagent.nix`](./oh-my-openagent.nix)):

| Key                              | Value                                 | Why                                                                  |
| -------------------------------- | ------------------------------------- | -------------------------------------------------------------------- |
| `retry_on_errors`                | `[402, 429, 500, 502, 503, 504, 529]` | 402 = credits off; 529 = Anthropic overloaded                        |
| `max_fallback_attempts`          | `5`                                   | chains are 3–5 deep                                                  |
| `cooldown_seconds`               | `14400` (4 h)                         | throttled model stays benched for the session (state is per-session) |
| `timeout_seconds`                | `30`                                  | hang safety net                                                      |
| `restore_primary_after_cooldown` | `false`                               | pointless with a 4 h cooldown; new sessions re-probe primary anyway  |

Fallback state is **per-session and in-memory** — a new session always re-probes the primary model once (~2s) before
switching. That is the self-healing path: when weekly limits reset, sessions land on Fable/Opus again with zero
intervention.

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
OAuth tokens, picks a free TUI loopback `--port` from the granted pool (see below), and execs `nono run` with the
profile. See the script header for the full input contract.

## Concurrent TUI sessions (loopback port pool)

The TUI's Go frontend talks to its TS backend over a `127.0.0.1` HTTP server, and nono blocks all localhost TCP unless a
port is explicitly granted (`open_port`). Linux nono has no `:0`/port-range grant, so a **pool** of ports is granted
(`open_port: [4099, 4100, 4101, 4102, 4103]` in [`nono-profile.jsonc`](./nono-profile.jsonc)) and
[`opencode-launch.sh`](../../scripts/opencode-launch.sh) probes them at startup (bash `/dev/tcp`), binding the first
free one. Each concurrent TUI gets a distinct granted port, so up to **5 OpenCode TUI sessions** run at once. A
user-supplied `--port` and all subcommands pass through untouched. Headless `opencode run` has no loopback split and is
unaffected either way.

The pool size is set in two places that must stay in sync: the `open_port` list in the profile and `OC_TUI_PORT_BASE` /
`OC_TUI_PORT_COUNT` in [`default.nix`](./default.nix). To allow more concurrent sessions, add ports to the profile list
and bump `OC_TUI_PORT_COUNT` to match.

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

Enabled on the Wayland desktop hosts (orion, p51); left `false` on non-graphical hosts (wsl-cab, iso, edge). When
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

## Phantom save-profile prompts

On exit, nono's save-profile heuristic scans recently-referenced strings and offers to persist any that look like paths.
OpenCode slash-command names (surfaced from `.claude/skills/*/SKILL.md` and the opencode skills dirs) start with `/`, so
they get misread as top-level dirs and shown as phantom `grant /<command> (read+write)` prompts — even though the same
dialog reports `No path denials were observed`.

The `filesystem.suppress_save_prompt` list in [`nono-profile.jsonc`](./nono-profile.jsonc) silences these for every
slash-command exposed to the sandbox. Per the nono schema it "does not grant access, remove deny rules, or hide
diagnostic output" — enforcement is unchanged; only the bogus prompt is suppressed. If a newly added skill triggers the
same phantom prompt, add its `/<command>` name to that list.

## See also

- [OMO Agent-Model Matching Guide](https://omo.dev/docs#agent-model-matching) — full fallback chains per agent.
- [OpenCode provider docs](https://opencode.ai/docs/providers/) — provider configuration reference.
