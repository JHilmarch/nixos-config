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

## Copilot CLI (Jailed)

The `copilot-jailed` command runs GitHub Copilot CLI inside a jail sandbox using `jail-nix`. The jail provides namespace
isolation while allowing network access, git operations, and configured MCP tools.

### Authentication

Copilot CLI authenticates via GitHub Enterprise licensing. Run:

```bash
gh auth login
```

Follow the prompts to authenticate with your GitHub Enterprise account. The jail forwards the `GH_TOKEN` and
`GITHUB_TOKEN` environment variables automatically.

### Available tools inside the jail

- **Git** and **GitHub CLI** — for repository operations
- **MCP servers**: mcp-nixos, azure-mcp, playwright, mcp-proxy, azure-devops

### Skills

The `using-git-worktrees` skill is available for isolated feature development.

### Azure DevOps MCP (PAT authentication)

The Azure DevOps MCP requires a Personal Access Token (PAT) set as an environment variable. Set it manually in your fish
config:

```fish
set -Ux AZURE_DEVOPS_PAT <your-pat>
```

The `-Ux` flag makes it a universal variable that persists across restarts. The jail forwards `AZURE_DEVOPS_PAT`
automatically.

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

From a WSL shell (NixOS), you can quickly smoke-test MCP servers:

```bash
# Test Azure MCP
azure-mcp-server

# Test Playwright MCP
mcp-server-playwright
```
