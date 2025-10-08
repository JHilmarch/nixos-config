# Azure MCP Server overlay

This overlay packages the [Azure MCP Server](https://www.nuget.org/packages/Azure.Mcp) (Azure.Mcp) from
the published .nupkg and exposes a CLI named **azure-mcp-server** that runs on .NET 10.

## Build targets

- Package: .#azure-mcp-server

## Quick start

- `nix build .#azure-mcp-server`
- Run the tool from the result:
  - `./result/bin/azure-mcp-server --help`
