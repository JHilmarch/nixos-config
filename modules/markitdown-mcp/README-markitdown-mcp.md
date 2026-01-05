# MarkItDown MCP module

This module packages the [MarkItDown MCP Server](https://github.com/microsoft/markitdown) from Microsoft. MarkItDown
converts various document formats (PDF, Office, images, audio, etc.) to Markdown.

The module builds the Python package from source using a custom Python environment with pinned `mcp` SDK version. It
also includes a wrapper script that sets up required environment variables for plugins (`ffmpeg` and `exiftool`).

## Build targets

- Module: `.#nixosModules.markitdown-mcp`

## Enable/disable module per host

This module can be toggled per host via the `services.markitdown-mcp.enable` option in the host's `configuration.nix`:

```nix
{
  services.markitdown-mcp.enable = true;
}
```

When enabled, the `markitdown-mcp` command is available system-wide.

## Bump version and rebuild

1. Pick the new version from GitHub releases: https://github.com/microsoft/markitdown/releases

1. Update `markitdownVersion` in `modules/markitdown-mcp/default.nix`

1. Update the source hash:

   - Temporarily set a fake hash: `hash = lib.fakeHash;`
   - Run `nix flake check` or build for the host
   - Copy the wanted hash from the error into `markitdownSrc.hash`

1. If the MCP SDK version needs updating, update the `mcp` package override:

   - Find the new version from PyPI: https://pypi.org/project/mcp/
   - Update `version` and `src.hash` in the `mcp` override

1. Apply the configuration:

   ```fish
   sudo nixos-rebuild switch --flake .#nixos-orion
   ```

1. Verify it works:

   ```fish
   markitdown-mcp --help
   ```

Conventional commit suggestion (for when you commit)

- feat(modules/markitdown-mcp): bump to vX.Y.Z

## Notes

- The module uses `pkgs.unstable` for the Python package build
- The wrapper sets up `EXIFTOOL_PATH` and `FFMPEG_PATH` for plugin support
- The `MARKITDOWN_ENABLE_PLUGINS` environment variable is set to `True`
