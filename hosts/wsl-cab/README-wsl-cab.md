# NixOS on WSL CAB

[Docs](https://nix-community.github.io/NixOS-WSL/)

## Build

To build the WSL tarball with Nix:

```bash
sudo nix run .#nixosConfigurations.wsl-cab.config.system.build.tarballBuilder
```

## Install WSL and import NixOS

- Install WSL
  ```powershell
  wsl --install --no-distribution
  ```
- Double-click on the downloaded `.wsl` file to import it.
- Verify the result:
  ```powershell
  wsl -l -v
  ```

## Set sudo password (optional)

First login: set your password (needed for sudo).

```bash
passwd
```

## GitHub authentication

The wrapped GitHub MCP Server uses the access token from GitHub CLI to authenticate. Login with `gh auth login`.

## Configure GitHub Copilot

```json
{
  "servers": {
    "context7": {
      "command": "wsl",
      "args": [
        "-d",
        "NixOS",
        "--",
        "context7"
      ]
    },
    "nuget": {
      "command": "wsl",
      "args": [
        "-d",
        "NixOS",
        "--",
        "mcp-nuget"
      ]
    },
    "azure": {
      "command": "wsl",
      "args": [
        "-d",
        "NixOS",
        "--",
        "azure-mcp-server"
      ]
    },
    "github": {
      "command": "wsl",
      "args": [
        "-d",
        "NixOS",
        "--",
        "github-mcp-server"
      ]
    },
    "awesome-copilot": {
      "command": "wsl",
      "args": [
        "-d",
        "NixOS",
        "--",
        "awesome-copilot"
      ]
    },
    "ms-learn": {
      "command": "wsl",
      "args": [
        "-d",
        "NixOS",
        "--",
        "mcp-proxy",
        "--transport",
        "streamablehttp",
        "https://learn.microsoft.com/api/mcp"
      ]
    },
    "markitdown": {
      "command": "wsl",
      "args": [
        "-d",
        "NixOS",
        "--",
        "markitdown-mcp"
      ]
    }
  }
}
```

### Test the MCP proxy inside WSL

From a WSL shell (NixOS), you can quickly smoke-test the MS Learn MCP over HTTP via the proxy:

```bash
mcp-proxy --transport streamablehttp https://learn.microsoft.com/api/mcp
```

If you see initialization logs rather than a 405 error, the proxy is using the correct transport (streamable HTTP) and
is ready to be used from Copilot.
