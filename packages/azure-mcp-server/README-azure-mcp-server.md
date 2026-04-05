# Azure MCP Server package

This package wraps the [Azure MCP Server](https://www.nuget.org/packages/Azure.Mcp) (Azure.Mcp) from the published
.nupkg and exposes a CLI named `azure-mcp-server` that runs on .NET 10.

## Build targets

- Package: `.#azure-mcp-server`

## Update

```fish
fish tools/update-packages/update-packages.fish update azure-mcp-server
```
