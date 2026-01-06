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

## Bump version and rebuild

1. Check the latest release on GitHub: https://github.com/upstash/context7/releases

1. Update the version and hashes in `packages/context7-mcp/default.nix`:

   ```nix
   pname = "context7-mcp";
   version = "x.x.x";  # Update this

   src = fetchFromGitHub {
     owner = "upstash";
     repo = "context7";
     rev = "@upstash/context7-mcp@x.x.x";  # Update this
     hash = lib.fakeHash;  # Update this (nix-prefetch-github)
   };

   pnpmDeps = pnpm_10.fetchDeps {
     inherit pname version src;
     hash = lib.fakeHash;  # Update this
     fetcherVersion = 1;
   };
   ```

1. Get the new hashes:

   ```bash
   # Source hash
   nix run nixpkgs#nix-prefetch-github -- --rev refs/tags/@upstash/context7-mcp@x.x.x upstash context7

   # pnpmDeps hash (prefetch the package, then look at the hash)
   nix build .#context7-mcp 2>&1 | grep "got:" | head -1
   ```

1. Build and test:

   ```bash
   nix build .#context7-mcp
   ./result/bin/context7-mcp --help
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
