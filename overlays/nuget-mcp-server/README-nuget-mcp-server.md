# NuGet MCP Server overlay

This overlay packages the [NuGet MCP Server](https://www.nuget.org/packages/NuGet.Mcp.Server) (NuGet.Mcp.Server) from
the published .nupkg and exposes a CLI named **mcp-nuget** that runs on .NET 10.

## Build targets

- Package: .#mcp-nuget

## Quick start

- `nix build .#mcp-nuget`
- Run the tool from the result:
  - `./result/bin/mcp-nuget --help`
