# Context7 MCP

This package provides [Context7 MCP](https://github.com/upstash/context7), which serves up-to-date code documentation
for LLMs.

## Build targets

- Package: `.#packages.x86_64-linux.context7-mcp` (or `.#context7-mcp` for short)

## Usage

The binary `context7-mcp` requires:

- `CONTEXT7_TOKEN` environment variable (or `--api-key` flag)
- `--transport stdio` flag (included in wrapper scripts)

### Authentication

Get your token from: https://context7.upstash.com

### Per-host wrappers

Two wrapper modules are provided for different authentication methods:

#### `modules/context7/sops-wrapper.nix`

For NixOS hosts with SOPS integration. Wraps the binary as `context7-with-sops` and automatically loads the API token
from the SOPS-encrypted secret `context7_pat`.

Used by: `nixos-orion`

#### `modules/context7/env-var-wrapper.nix`

For hosts that use environment variables (including WSL with Windows fallback). Wraps the binary as `context7-with-env`
and:

- Reads `CONTEXT7_TOKEN` from environment
- Falls back to Windows User environment variable (WSL compatibility)
- Works in rate-limited mode if no token is set

Used by: `wsl-cab`

## Update

```fish
fish tools/update-packages/update-packages.fish update context7-mcp
```

## Package details

- **Homepage**: https://github.com/upstash/context7
- **License**: MIT
- **Platforms**: Unix (Linux, macOS)

## Wrapper scripts

The package includes a wrapper script that:

- Supports `CONTEXT7_TOKEN` environment variable
- Supports `CONTEXT7_TOKEN_FILE` for SOPS integration
- Automatically generates `CLIENT_IP_ENCRYPTION_KEY` if not set (to avoid warning)
- Defaults to `--transport stdio` required for Node.js execution
