# Azure MCP Server overlay

This overlay packages the [Azure MCP Server](https://www.nuget.org/packages/Azure.Mcp) (Azure.Mcp) from the published
.nupkg and exposes a CLI named `azure-mcp-server` that runs on .NET 10.

The overlay pins all transitive NuGet packages in `deps.json`. You must regenerate this file whenever bumping the
Azure.Mcp version.

## Build targets

- Package: `.#azure-mcp-server`

## Bump version and rebuild

1. Pick the new version from NuGet: https://www.nuget.org/packages/Azure.Mcp

1. Regenerate the pinned dependencies for this overlay using the helper script. This step is required, otherwise the
   build will fail or use stale dependencies.

   Using nix-shell to provide tools (recommended):

   - `bash scripts/generate-nuget-deps.sh --ensure-sibling azure.mcp:azure.mcp.linux-x64 Azure.Mcp <Version> overlays/azure-mcp-server/deps.json`

   Examples:

   - `bash scripts/generate-nuget-deps.sh --ensure-sibling azure.mcp:azure.mcp.linux-x64 Azure.Mcp 0.8.6 overlays/azure-mcp-server/deps.json`

   The script resolves the tool via `dotnet tool install`, computes sha256 for each package from nuget.org and writes
   them to `overlays/azure-mcp-server/deps.json`.

1. Build the package:

   - `nix build .#azure-mcp-server`

1. Test run from the build result:

   - `./result/bin/azure-mcp-server --help`

Notes:

- If you run the script without a version, it will resolve the latest available:
  `bash scripts/generate-nuget-deps.sh Azure.Mcp overlays/azure-mcp-server/deps.json`.
- Review the diff of `deps.json` into version control once verified.
