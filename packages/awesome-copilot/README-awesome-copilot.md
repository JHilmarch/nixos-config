# Awesome Copilot package

This package wraps the [Awesome Copilot](https://github.com/microsoft/mcp-dotnet-samples/tree/main/awesome-copilot) MCP
server from the [microsoft/mcp-dotnet-samples](https://github.com/microsoft/mcp-dotnet-samples) repository and exposes a
CLI named `awesome-copilot` that runs on .NET 10.

## Build targets

- Package: `.#awesome-copilot`
- Patched variant (with MCP logging redirected to stderr): `.#awesome-copilot-patched`

## Update

```fish
fish tools/update-packages/update-packages.fish update awesome-copilot
```
