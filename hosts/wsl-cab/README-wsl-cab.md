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

## Context7 Authentication (optional)

The Context7 MCP server provides up-to-date code documentation. To use it without rate limits, set the `CONTEXT7_TOKEN`
environment variable:

### Temporary (current session only)

```bash
export CONTEXT7_TOKEN="your-context7-token-here"
```

### Permanent (add to Fish shell)

Create or edit `~/.config/fish/conf.d/context7.fish`:

```fish
# Context7 MCP token for unlimited access
# Get your token from: https://context7.upstash.com
if not set -q CONTEXT7_TOKEN
    set -gx CONTEXT7_TOKEN "your-context7-token-here"
end
```

Then reload your shell and verify:

```bash
source ~/.config/fish/conf.d/context7.fish
echo $CONTEXT7_TOKEN
```

### Permanent (Windows environment variable)

Alternatively, set the environment variable in Windows so it's available to WSL and the Context7 MCP module:

1. Open PowerShell and run (sets user-level variable):

```powershell
[System.Environment]::SetEnvironmentVariable('CONTEXT7_TOKEN', 'your-token-here', 'User')
```

1. Restart your WSL session for the change to take effect:

```powershell
wsl --shutdown
```

**Notes:**

- User-level variables are stored in `HKEY_CURRENT_USER\Environment`
- To set system-wide (all users): use `'Machine'` instead of `'User'` (requires admin)
- You can also set variables via Windows Settings GUI: Settings > System > About > Advanced system settings >
  Environment Variables

**Note:** The token is stored in plain text in your Fish config. This is acceptable for WSL development environments but
not recommended for multi-user systems.

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
        "context7-with-env"
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
