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

| Domain                          | Category         | Why blocked if missing                                                       |
| ------------------------------- | ---------------- | ---------------------------------------------------------------------------- |
| `api.z.ai`                      | LLM provider     | GLM-5.2 inference fails; orchestrators (sisyphus/prometheus/atlas) go dark   |
| `api.anthropic.com`             | LLM provider     | Direct Anthropic API calls fail (fallback path for non-OAuth usage)          |
| `claude.ai`                     | LLM provider     | OAuth token refresh fails; `@ex-machina` plugin dies; all Claude models fail |
| `opencode.ai`                   | LLM provider     | OpenCode Go OAuth refresh fails; kimi/qwen/minimax models unavailable        |
| `api.openai.com`                | LLM provider     | Hephaestus completely non-functional; last-resort fallbacks fail             |
| `*.openai.com`                  | LLM provider     | CDN/streaming endpoints for OpenAI; same failure mode as above               |
| `models.dev`                    | LLM provider     | Model catalog lookups fail; provider routing may degrade                     |
| `registry.npmjs.org`            | Package registry | npm install fails inside agent tasks                                         |
| `*.npmjs.org`                   | Package registry | npm CDN/metadata endpoints; same failure mode                                |
| `github.com`                    | Package registry | git clone over HTTPS fails; GitHub Actions, releases unreachable             |
| `*.github.com`                  | Package registry | GitHub subdomains (assets, pages, etc.)                                      |
| `objects.githubusercontent.com` | Package registry | GitHub release asset downloads fail                                          |
| `codeload.github.com`           | Package registry | GitHub archive downloads (zip/tarball) fail                                  |
| `raw.githubusercontent.com`     | Package registry | Raw file fetches from GitHub repos fail                                      |
| `api.github.com`                | Package registry | GitHub API calls fail; MCP github-personal/github-work tools fail            |
| `pypi.org`                      | Package registry | pip install fails                                                            |
| `*.pypi.org`                    | Package registry | PyPI CDN/metadata endpoints                                                  |
| `files.pythonhosted.org`        | Package registry | Python package wheel/sdist downloads fail                                    |
| `crates.io`                     | Package registry | cargo fetch/build fails                                                      |
| `static.crates.io`              | Package registry | Crate file downloads fail                                                    |
| `*.crates.io`                   | Package registry | crates.io CDN endpoints                                                      |
| `api.nuget.org`                 | Package registry | dotnet restore fails                                                         |
| `*.nuget.org`                   | Package registry | NuGet CDN/metadata endpoints                                                 |
| `cache.nixos.org`               | Nix substituter  | Nix binary cache misses; every nix build falls back to source compilation    |
| `*.nixos.org`                   | Nix substituter  | NixOS channel metadata, search.nixos.org MCP queries                         |
| `search.nixos.org`              | Nix substituter  | mcp-nixos tool queries fail                                                  |
| `cache.numtide.com`             | Nix substituter  | numtide binary cache misses (host-specific; see note below)                  |
| `api.exa.ai`                    | Research tool    | websearch tool (Exa backend) returns no results                              |
| `grep.app`                      | Research tool    | grep_app tool fails entirely                                                 |
| `context7.com`                  | Research tool    | context7 MCP tool fails                                                      |
| `*.context7.com`                | Research tool    | context7 CDN/API subdomains                                                  |

______________________________________________________________________

## LLM Providers

### z.ai (GLM)

**Domain:** `api.z.ai` **Auth:** SOPS env var `ZAI_API_KEY`, injected by the jail wrapper before process start.
**Models:** GLM-5.2, GLM-5.1, GLM-5-turbo, GLM-5v-turbo. **Role:** Default orchestrator for sisyphus, prometheus, atlas,
and most category workers.

Blocking `api.z.ai` silences the primary inference path for every orchestrator-tier agent. The first fallback
(Anthropic) takes over, but at higher cost and lower throughput.

### Anthropic (Claude)

**Domains:** `api.anthropic.com`, `claude.ai` **Auth:** `@ex-machina/opencode-anthropic-auth` plugin (OAuth). Tokens
stored in `~/.local/share/opencode/auth.json`, synced from `~/.claude/.credentials.json` on startup. **Models:** Claude
Opus 4.8, Sonnet 4.6, Haiku 4.5. **Role:** First fallback for orchestrators; primary for deep/review tier.

`claude.ai` is the single most fragile domain in this allowlist. The `@ex-machina` plugin refreshes OAuth tokens against
`claude.ai` at runtime. If `claude.ai` is blocked, token refresh fails silently: requests to `api.anthropic.com` start
returning auth errors (401/403), not connection errors. The failure looks like a provider misconfiguration, not a
network block. All Claude models become unavailable. Blocking `api.anthropic.com` directly cuts inference; blocking
`claude.ai` cuts the auth refresh that keeps inference alive.

See [README.md](./README.md) for the full OAuth flow and the `@ex-machina` plugin rationale.

### OpenAI

**Domains:** `api.openai.com`, `*.openai.com` **Auth:** SOPS env var `OPENAI_API_KEY`. **Models:** GPT-5.5. **Role:**
Hephaestus primary (no fallback). Last-resort fallback for deep/review tier.

Hephaestus is the only agent with OpenAI as its primary model and no fallback chain. Blocking OpenAI makes Hephaestus
completely non-functional. For all other agents, OpenAI is the second or third fallback; blocking it degrades only on
triple-failure scenarios. `*.openai.com` covers CDN and streaming endpoints used during inference.

### OpenCode Go

**Domain:** `opencode.ai` **Auth:** `opencode auth login --provider opencode-go` (OAuth). Tokens in
`~/.local/share/opencode/`. **Models:** Kimi K2.7-code, Qwen 3.7-plus, MiniMax M3, MiniMax M2.7. **Role:** Second
fallback for orchestrators; primary for visual/artistry and utility tiers.

Blocking `opencode.ai` prevents OAuth token refresh. The utility tier (kimi/qwen/minimax) goes dark, and the
orchestrator second-fallback path fails. The $10/mo flat subscription covers all four models.

______________________________________________________________________

## Package Registries

These domains are needed when the agent runs package install, build, or fetch commands inside tasks.

### npm

`registry.npmjs.org`, `*.npmjs.org`

npm install and package metadata. `*.npmjs.org` covers CDN and scoped-package endpoints.

### GitHub

`github.com`, `*.github.com`, `objects.githubusercontent.com`, `codeload.github.com`, `raw.githubusercontent.com`,
`api.github.com`

HTTPS git clone, release downloads, raw file fetches, and the GitHub REST API. `api.github.com` is also required by the
MCP github-personal and github-work servers (see [MCP Servers](#mcp-servers)).

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

Queries `search.nixos.org` (already listed under NixOS registries). No additional domains.

### github-personal / github-work

Both servers call `api.github.com`. Already listed under GitHub registries. No additional domains beyond the GitHub
block above.

______________________________________________________________________

## Built-in OMO/OpenCode Tools

### websearch (Exa)

**Domain:** `api.exa.ai`

The websearch tool sends queries to the Exa search API. Blocking `api.exa.ai` returns empty results with no error
surfaced to the agent.

### grep_app

**Domain:** `grep.app`

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

### Port 22: SSH Egress

`network.allow_domain` is an HTTP(S) proxy allowlist. It operates via CONNECT tunnel and TLS interception on port 443
(and port 80). It does NOT intercept or filter raw TCP connections on other ports.

Git over SSH (`git clone git@github.com:...`) opens a raw TCP connection to port 22. This connection bypasses the nono
proxy entirely. The nono layer cannot enforce an allowlist for raw TCP outbound traffic in v1.

**v1 resolution (option 3 from issue #124):** Documented exception. SSH egress remains unfiltered at the nono layer.
`git clone` over SSH works, but is not allowlist-enforced. The story #117 acceptance criteria explicitly states "SSH
egress for git over SSH is allowed," which this resolution satisfies literally. A future nono version with raw-TCP
outbound filtering would close this gap.

Flagged as a product-decision follow-up for story #117.

### webfetch and Arbitrary URLs

Documented in [Built-in OMO/OpenCode Tools](#built-in-omoopencode-tools) above. webfetch is not domain-scoped by design;
the allowlist cannot enumerate every URL an agent might fetch. The v1 resolution accepts that webfetch fails closed for
unlisted domains. Common research domains (`api.exa.ai`, `grep.app`, `context7.com`) are explicitly listed to cover the
most frequent cases.

Flagged as a product-decision follow-up for story #117.

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
