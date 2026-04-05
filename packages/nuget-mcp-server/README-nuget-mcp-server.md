# NuGet MCP Server package

This package wraps the [NuGet MCP Server](https://www.nuget.org/packages/NuGet.Mcp.Server) (NuGet.Mcp.Server) from the
published .nupkg and exposes a CLI named `mcp-nuget` that runs on .NET 10.

## Build targets

- Package: `.#mcp-nuget`

## Update

```fish
fish tools/update-packages/update-packages.fish update nuget-mcp-server
```
