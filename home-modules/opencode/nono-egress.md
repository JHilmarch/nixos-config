# OpenCode Nono Profile: Egress Allowlist

The nono profile (`nono-profile.jsonc`) enforces default-deny egress for the OpenCode agent process. Every outbound
HTTPS connection must match an entry in `network.allow_domain`; unmatched requests are blocked at the proxy layer. This
replaces the jail-nix `network` combinator, which granted full host network access with no filtering. The allowlist
below is the authoritative record of what the agent is permitted to reach and why.

`network.allow_domain` is an HTTP(S) proxy allowlist only. It operates via CONNECT tunnel and optional TLS interception.
It does NOT filter raw TCP. See [Design Tensions](#design-tensions) for the implications.

______________________________________________________________________

## Quick Reference

All domains in one flat table. The encoded entries in `nono-profile.jsonc` must match this list exactly.

| Domain                                 | Category         | Why blocked if missing                                                       |
| -------------------------------------- | ---------------- | ---------------------------------------------------------------------------- |
| `api.z.ai`                             | LLM provider     | GLM-5.2 inference fails; orchestrators (sisyphus/prometheus/atlas) go dark   |
| `api.anthropic.com`                    | LLM provider     | Direct Anthropic API calls fail (fallback path for non-OAuth usage)          |
| `claude.ai`                            | LLM provider     | OAuth token refresh fails; `@ex-machina` plugin dies; all Claude models fail |
| `opencode.ai`                          | LLM provider     | OpenCode Go OAuth refresh fails; kimi/qwen/minimax models unavailable        |
| `api.openai.com`                       | LLM provider     | Hephaestus completely non-functional; last-resort fallbacks fail             |
| `*.openai.com`                         | LLM provider     | CDN/streaming endpoints for OpenAI; same failure mode as above               |
| `api.opencode.ai`                      | LLM provider     | OpenCode Go inference fails; kimi/qwen/minimax requests cannot reach the API |
| `models.dev`                           | LLM provider     | Model catalog lookups fail; provider routing may degrade                     |
| `registry.npmjs.org`                   | Package registry | npm install fails inside agent tasks                                         |
| `*.npmjs.org`                          | Package registry | npm CDN/metadata endpoints; same failure mode                                |
| `github.com`                           | Package registry | git clone over HTTPS fails; GitHub Actions, releases unreachable             |
| `*.github.com`                         | Package registry | GitHub subdomains (assets, pages, etc.)                                      |
| `objects.githubusercontent.com`        | Package registry | GitHub release asset downloads fail (legacy host)                            |
| `release-assets.githubusercontent.com` | Package registry | GitHub release asset downloads fail (current CDN host)                       |
| `codeload.github.com`                  | Package registry | GitHub archive downloads (zip/tarball) fail                                  |
| `raw.githubusercontent.com`            | Package registry | Raw file fetches from GitHub repos fail                                      |
| `api.github.com`                       | Package registry | GitHub API calls fail; MCP github-personal/github-work tools fail            |
| `pypi.org`                             | Package registry | pip install fails                                                            |
| `*.pypi.org`                           | Package registry | PyPI CDN/metadata endpoints                                                  |
| `files.pythonhosted.org`               | Package registry | Python package wheel/sdist downloads fail                                    |
| `crates.io`                            | Package registry | cargo fetch/build fails                                                      |
| `static.crates.io`                     | Package registry | Crate file downloads fail                                                    |
| `*.crates.io`                          | Package registry | crates.io CDN endpoints                                                      |
| `api.nuget.org`                        | Package registry | dotnet restore fails                                                         |
| `*.nuget.org`                          | Package registry | NuGet CDN/metadata endpoints                                                 |
| `cache.nixos.org`                      | Nix substituter  | Nix binary cache misses; every nix build falls back to source compilation    |
| `*.nixos.org`                          | Nix substituter  | NixOS channel metadata, search.nixos.org MCP queries                         |
| `search.nixos.org`                     | Nix substituter  | mcp-nixos tool queries fail                                                  |
| `nixhub.io`                            | Nix substituter  | mcp-nixos `nix_versions` / NixHub version-history queries fail closed        |
| `noogle.dev`                           | Nix substituter  | mcp-nixos Noogle function search / browse fails closed                       |
| `cache.numtide.com`                    | Nix substituter  | numtide binary cache misses (host-specific; see note below)                  |
| `mcp.exa.ai`                           | Research tool    | websearch tool (Exa MCP backend) fails; needs `EXA_API_KEY` for paid access  |
| `mcp.grep.app`                         | Research tool    | grep_app MCP server unreachable; code search fails                           |
| `grep.app`                             | Research tool    | grep.app site (referenced by grep_app; Vercel-challenge-guarded)             |
| `context7.com`                         | Research tool    | context7 MCP tool fails                                                      |
| `*.context7.com`                       | Research tool    | context7 CDN/API subdomains                                                  |

______________________________________________________________________

## LLM Providers

### z.ai (GLM)

**Domain:** `api.z.ai` **Auth:** SOPS env var `ZAI_API_KEY`, injected by the jail wrapper before process start.

### Anthropic (Claude)

**Domains:** `api.anthropic.com`, `claude.ai` **Auth:** `@ex-machina/opencode-anthropic-auth` plugin (OAuth). Tokens
stored in `~/.local/share/opencode/auth.json`, synced from `~/.claude/.credentials.json` on startup.

`claude.ai` is the single most fragile domain in this allowlist. The `@ex-machina` plugin refreshes OAuth tokens against
`claude.ai` at runtime. If `claude.ai` is blocked, token refresh fails silently: requests to `api.anthropic.com` start
returning auth errors (401/403), not connection errors. The failure looks like a provider misconfiguration, not a
network block. All Claude models become unavailable. Blocking `api.anthropic.com` directly cuts inference; blocking
`claude.ai` cuts the auth refresh that keeps inference alive.

See [README.md](./README.md) for the full OAuth flow and the `@ex-machina` plugin rationale.

### OpenAI

**Domains:** `api.openai.com`, `*.openai.com` **Auth:** SOPS env var `OPENAI_API_KEY`.

### OpenCode Go

**Domains:** `opencode.ai`, `api.opencode.ai` **Auth:** `opencode auth login --provider opencode-go` (OAuth). Tokens in
`~/.local/share/opencode/`.

`opencode.ai` serves the OAuth login/console; `api.opencode.ai` serves the inference API the models actually call.
Blocking `opencode.ai` prevents OAuth token refresh; blocking `api.opencode.ai` cuts inference even when the token is
valid.

______________________________________________________________________

## Package Registries

These domains are needed when the agent runs package install, build, or fetch commands inside tasks.

### npm

`registry.npmjs.org`, `*.npmjs.org`

npm install and package metadata. `*.npmjs.org` covers CDN and scoped-package endpoints.

### GitHub

`github.com`, `*.github.com`, `objects.githubusercontent.com`, `release-assets.githubusercontent.com`,
`codeload.github.com`, `raw.githubusercontent.com`, `api.github.com`

HTTPS git clone, release downloads, raw file fetches, and the GitHub REST API. `api.github.com` is also required by the
MCP github-personal and github-work servers (see [MCP Servers](#mcp-servers)). Release binaries are served from two
hosts: `objects.githubusercontent.com` (legacy) and `release-assets.githubusercontent.com` (current CDN). The `gh` CLI
and tool/binary installers inside agent tasks hit both depending on the asset's age.

### PyPI

`pypi.org`, `*.pypi.org`, `files.pythonhosted.org`

pip install and Python package downloads. `files.pythonhosted.org` hosts the actual wheel and sdist files.

### crates.io

`crates.io`, `static.crates.io`, `*.crates.io`

cargo fetch and crate downloads. `static.crates.io` serves the crate files; `*.crates.io` covers CDN endpoints.

### NuGet

`api.nuget.org`, `*.nuget.org`

dotnet restore and NuGet package downloads. Used by the NuGet builder in `functions/`.

### NixOS

`cache.nixos.org`, `*.nixos.org`, `search.nixos.org`

`cache.nixos.org` is the primary Nix binary cache. A miss here forces source compilation for every affected derivation.
`*.nixos.org` covers channel metadata and other NixOS infrastructure. `search.nixos.org` is queried directly by the
mcp-nixos MCP server.

______________________________________________________________________

## MCP Servers

MCP servers run as local processes (localhost IPC via `open_port`). They make outbound HTTPS calls on behalf of the
agent. The domains below are what those servers reach, not the servers themselves.

### mcp-nixos

Queries `search.nixos.org` (covered by `*.nixos.org`) for package/option search. Also reaches two domains outside the
NixOS infrastructure block:

- `nixhub.io` — package version history (`nix_versions`, NixHub lookups). Blocked → version-history queries fail closed.
- `noogle.dev` — Noogle function search / browse. Blocked → Noogle queries fail closed.

Both are now listed under NixOS registries in the profile.

### github-personal / github-work

Both servers call `api.github.com`. Already listed under GitHub registries. No additional domains beyond the GitHub
block above.

______________________________________________________________________

## Built-in OMO/OpenCode Tools

### websearch (Exa)

**Domain:** `mcp.exa.ai`

OMO's websearch tool is a remote MCP server at `https://mcp.exa.ai/mcp` (see
`packages/omo-opencode/src/mcp/websearch.ts`). It works keyless on Exa's free tier but returns HTTP 402 (Payment
Required) once quota is exhausted. Set `EXA_API_KEY` (sourced from the sops `agents.env` template and allowlisted in
`environment.allow_vars`) — OMO sends it as `Authorization: Bearer $EXA_API_KEY`. Blocking `mcp.exa.ai` makes the
websearch tool fail entirely.

### grep_app

**Domains:** `mcp.grep.app` (MCP server actually used), `grep.app` (site)

The grep_app tool queries grep.app for code search across public GitHub repos. Blocking it makes the tool return errors.

### context7

**Domains:** `context7.com`, `*.context7.com`

The context7 MCP tool fetches library documentation. `*.context7.com` covers API subdomains.

### webfetch

**Design tension:** webfetch can fetch any HTTPS URL by design. It does not pre-declare target domains. This
fundamentally conflicts with a strict allowlist: an agent can call webfetch with an arbitrary URL, and the request will
be blocked if the domain is not in `allow_domain`. The v1 resolution is to include common research domains in the
allowlist and accept that webfetch fails closed (blocked) for unlisted domains. Agents that need to fetch an unlisted
domain will get a connection error. This is the correct failure mode for a default-deny policy, but it means webfetch is
not fully functional for arbitrary URLs.

Flagged as a product-decision follow-up for story #117.

______________________________________________________________________

## Nix Substituters

### cache.nixos.org

Listed under [NixOS registries](#nixos) above. Required on all hosts.

### cache.numtide.com

**Domain:** `cache.numtide.com` **Hosts:** Host-specific. Enabled on hosts that use numtide packages or the numtide
NixOS modules.

Blocking this cache causes binary cache misses for numtide-provided derivations. Nix falls back to source compilation,
which is slow but not fatal. If a host does not use numtide packages, this entry has no effect.

______________________________________________________________________

## Design Tensions

### Raw TCP egress is blocked (incl. port 22 / SSH)

`network.allow_domain` is an HTTP(S) proxy allowlist on ports 80/443. nono's Landlock network layer blocks all direct
`connect()` — every port, including 22 and direct 443. Egress is possible only through the injected HTTP(S) proxy to an
allowlisted host; there is no raw-TCP passthrough.

Consequence: all network git fails inside the sandbox. `git fetch`/`pull`/`push`/`clone` against a remote open raw TCP
(SSH to port 22, or a direct HTTPS socket), which Landlock denies. This is the intended default-deny behavior, not a
gap.

The sandboxed agent therefore works locally only — commit, branch, `worktree add`, local `rebase`/`merge --ff-only`, and
file-based SSH commit signing all run without egress. Remote sync (`fetch`/`pull`/`push`) is done by the human from a
normal host shell outside the sandbox, where SSH and the YubiKey agent work as usual. `gh-personal`/`gh-work` (PRs,
issues, project board) still work inside the sandbox because they use the GitHub REST API over HTTPS to the allowlisted
`api.github.com`.

### webfetch and Arbitrary URLs

Documented in [Built-in OMO/OpenCode Tools](#built-in-omoopencode-tools) above. webfetch is not domain-scoped by design;
the allowlist cannot enumerate every URL an agent might fetch. The v1 resolution accepts that webfetch fails closed for
unlisted domains. Common research domains (`mcp.exa.ai`, `mcp.grep.app`, `context7.com`) are explicitly listed to cover
the most frequent cases.

Flagged as a product-decision follow-up for story #117.

### Loopback IPC: the TUI's localhost server

The TUI's Go frontend talks to its TS backend over a `127.0.0.1` HTTP server. nono sets `NO_PROXY=localhost,127.0.0.1`,
so that loopback bypasses the egress proxy into the kernel-level direct-connect block, crashing startup with
`permission denied 127.0.0.1:0` (surfaced as a generic `Effect.tryPromise` error with a misleading "no path denials"
footer). Headless `opencode run` has no loopback split and is unaffected.

`network.open_port` grants bidirectional localhost TCP on a fixed port (Linux nono has no `:0`/range grant), so the port
is pinned on both sides: `open_port: [4099]` in the profile and `--port 4099` in the wrapper (TUI path only; subcommands
and a user `--port` pass through). Verified: the loopback listen succeeds with the grant and fails `EACCES` without it.

### Loopback IPC: the hunk daemon session broker

The `hunk-review` skill drives live [hunk.dev](https://hunk.dev) reviews through `hunk session *` subcommands, which
reach the hunk session-broker daemon over `127.0.0.1:47657` (`HUNK_MCP_PORT` default). The daemon runs on the host,
started by the user's Hunk TUI; only the sandboxed client's loopback reach needs granting.

The same `NO_PROXY=localhost,127.0.0.1` loopback split that affects the TUI (above) denies `connect()` to that port by
default, so every `hunk session` call fails with `No active Hunk sessions.` even while Hunk is running. Adding `47657`
to `open_port` grants the loopback reach: nono then reports `ipc localhost:47657` and the socket connects.
`HUNK_MCP_PORT` is left at its default — pinning a custom port would require syncing the env var into the sandbox for no
benefit.

### Filesystem grants for the TUI: `/tmp` and `~/.local/state/opencode`

Two non-network grants the TUI needs, both failing as the same misleading `Effect.tryPromise` / "no path denials" error:

- **`/tmp`** — the Bun binary extracts its embedded OpenTUI render lib (`.so`) into `/tmp` and `dlopen()`s it at TUI
  startup. nono does not auto-grant `/tmp`, so the load fails and the TUI crashes (headless runs never load the
  renderer).
- **`$XDG_STATE_HOME/opencode`** — `models.dev` cache locks/logs live here; without the grant the lock `mkdir` fails
  `EACCES` and capability refresh dies (non-fatal but noisy).

Confirmed via `nono why` (`ALLOWED` with the grants, `DENIED` without).

> **Best-effort Landlock caveat:** on kernels without full Landlock ABI these denials may leak through, so the TUI can
> work on one host and crash on another. Trust `nono why`, not a single host's live run.

______________________________________________________________________

## Verification Recipe

The nono profile is encoded in `nono-profile.jsonc`. To verify egress filtering is active:

```fish
# Negative test — should be blocked (example.com is not in the allowlist):
nix shell nixpkgs#nono --command nono run --profile home-modules/opencode/nono-profile.jsonc -- curl -I https://example.com

# Positive spot-checks — should succeed:
nix shell nixpkgs#nono --command nono run --profile home-modules/opencode/nono-profile.jsonc -- curl -I https://api.github.com
nix shell nixpkgs#nono --command nono run --profile home-modules/opencode/nono-profile.jsonc -- curl -I https://registry.npmjs.org
```

The negative test must return a connection error (proxy block), not an HTTP response. If it returns HTTP 200, the
allowlist is not active.

**WSL2 caveat:** The nono guide (section 3, security) sets `wsl2_proxy_policy: "error"` as the default. On WSL2, if the
proxy-only mode cannot be kernel-enforced, nono refuses to run rather than falling back to unfiltered network access.
This is the correct behavior for a default-deny policy. If the verification recipe fails to launch on WSL2, check that
the nono version supports WSL2 proxy enforcement.

______________________________________________________________________

## Cross-Reference

The `network.allow_domain` entries encoding this allowlist live in:

```
home-modules/opencode/nono-profile.jsonc
```

That file is the machine-readable source of truth. This document is the human-readable rationale. If the two diverge,
`nono-profile.jsonc` is authoritative for what is actually enforced; this document should be updated to match.

The provider stack (four providers, three auth strategies) is documented in [README.md](./README.md). The per-agent
model matrix is in [`oh-my-openagent.nix`](./oh-my-openagent.nix).
