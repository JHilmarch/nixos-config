# NuGet MCP Server overlay

This overlay packages the [NuGet MCP Server](https://www.nuget.org/packages/NuGet.Mcp.Server) (NuGet.Mcp.Server) from
the published .nupkg and exposes a CLI named `mcp-nuget` that runs on .NET 10.

The overlay pins all transitive NuGet packages in `deps.json`. You must regenerate this file whenever bumping the
NuGet.Mcp.Server version.

## Build targets

- Package: `.#mcp-nuget`

## Bump version and rebuild

1. Pick the new version from NuGet: https://www.nuget.org/packages/NuGet.Mcp.Server

1. Regenerate the pinned dependencies for this overlay using the helper script. This step is required, otherwise the
   build will fail or use stale dependencies.

   Using nix-shell to provide tools (recommended):

   - `bash scripts/generate-nuget-deps.sh --ensure-sibling nuget.mcp.server:nuget.mcp.server.linux-x64 NuGet.Mcp.Server <Version> overlays/nuget-mcp-server/deps.json`

   Examples:

   - `bash scripts/generate-nuget-deps.sh --ensure-sibling nuget.mcp.server:nuget.mcp.server.linux-x64 NuGet.Mcp.Server 1.0.0 overlays/nuget-mcp-server/deps.json`

   The script resolves the tool via `dotnet tool install`, computes sha256 for each package from nuget.org and writes
   them to `overlays/nuget-mcp-server/deps.json`.

1. Build the package:

   - `nix build .#mcp-nuget`

1. Test run from the build result:

   - `./result/bin/mcp-nuget --help`

Notes:

- If you run the script without a version, it will resolve the latest available:
  `bash scripts/generate-nuget-deps.sh NuGet.Mcp.Server overlays/nuget-mcp-server/deps.json`.
- Review the diff of `deps.json` into version control once verified.
