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

## Update

```fish
fish tools/update-packages/update-packages.fish update markitdown-mcp
```

## Notes

- The module uses `pkgs.unstable` for the Python package build
- The wrapper sets up `EXIFTOOL_PATH` and `FFMPEG_PATH` for plugin support
- The `MARKITDOWN_ENABLE_PLUGINS` environment variable is set to `True`
