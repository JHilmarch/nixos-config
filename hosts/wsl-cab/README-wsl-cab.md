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
- Verify result:
  ```powershell
  wsl -l -v
  ```

## Set sudo password (optional)

First login: set your password (needed for sudo).

```bash
passwd
```

## GitHub Copilot CLI (copilot-jailed)

The Copilot CLI runs inside a `jail-nix` sandbox (`copilot-jailed`). The jail provides:

- Network access for API calls
- Read-write access to `~/.cache/copilot-cli`, `~/.config/copilot-cli`, `~/.copilot`, `~/.local/share/copilot-cli`
- Read-only access to `~/.gitconfig`, `~/.ssh`, `~/.config/git`
- MCP servers configured via `~/.copilot/mcp-config.json` (managed by Nix)
- Skills from `home-modules/copilot-cli/skills/` (auto-loaded)

### Authentication

GitHub Copilot CLI authenticates via `gh auth login` (native flow). No PATs or sops-nix needed — GitHub Enterprise
licensing provides the AI models.

### Azure DevOps MCP authentication

The jailed Copilot CLI expects these environment variables inside WSL:

- `AZURE_DEVOPS_ORG` - your Azure DevOps organization name
- `AZURE_DEVOPS_PAT` - your raw Azure DevOps Personal Access Token

To make them survive shell restarts and reboots in fish, set them as universal exported variables:

```fish
set -Ux AZURE_DEVOPS_ORG your-org
set -Ux AZURE_DEVOPS_PAT your-pat
```

The `copilot-jailed` wrapper forwards these variables into the jail and converts `AZURE_DEVOPS_PAT` into the
`PERSONAL_ACCESS_TOKEN` format expected by `azure-devops-mcp` by base64-encoding `copilot:<your-pat>`. The `copilot`
prefix is a required non-empty placeholder username; Azure DevOps ignores it and uses only the PAT portion for
authentication.

After rebuilding, the generated `~/.copilot/mcp-config.json` will contain an `azure-devops` MCP entry that launches the
server through the in-jail `copilot-azure-devops-mcp` wrapper.

## Other MCP Servers

```json
{
  "mcpServers": {
    "azure": {
      "command": "wsl",
      "args": [
        "-d",
        "NixOS",
        "--",
        "azure-mcp-server"
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
    "playwright": {
      "type": "local",
      "command": "wsl",
      "args": [
        "-d",
        "NixOS",
        "--",
        "mcp-server-playwright"
      ],
      "tools": [
        "*"
      ]
    }
  }
}
```

### Test MCP proxy inside WSL

From a WSL shell (NixOS), you can quickly smoke-test the MS Learn MCP over HTTP via proxy:

```bash
mcp-proxy --transport streamablehttp https://learn.microsoft.com/api/mcp
```

If you see initialization logs rather than a 405 error, the proxy is using correct transport (streamable HTTP) and is
ready to be used from Copilot.
