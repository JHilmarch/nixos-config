# NixOS on WSL CAB

[Docs](https://nix-community.github.io/NixOS-WSL/)

## Build

Build the WSL tarball and copy to USB (split for FAT32):

```fish
cd ~; and \
sudo nix run ~/code/nixos-config#nixosConfigurations.wsl-cab.config.system.build.tarballBuilder; and \
set -l f cab-(date +%s).wsl; and mv ~/nixos.wsl ~/$f; and \
pv -p -t -r -b ~/$f | split -b 1G - /run/media/jonatan/CORSAIR/$f.part-; and \
echo "Flushing to disk..."; sync &
sleep 1
while test (awk '/^Writeback:/{print $2}' /proc/meminfo) -gt 0
    printf "\r  %s kB remaining" (awk '/^Writeback:/{print $2}' /proc/meminfo)
    sleep 1
end
echo "Safe to eject."
```

Rejoin on Windows and copy to Temp folder (PowerShell):

```powershell
cmd /c "copy /b /y E:\cab-*.part-* C:\Temp\cab.wsl & del E:\cab-*.part-*"
```

## Install WSL and import NixOS

- Install the WSL:
  ```powershell
  wsl --install --from-file "C:\\Temp\cab.wsl" --name "NixOS-personal"
  ```
- Verify result:
  ```powershell
  wsl -l -v
  ```

## Set sudo password (optional)

First login: set your password (needed for sudo).

```bash
passwd
```

## GitHub Copilot CLI (copilot-fenced)

The Copilot CLI runs inside a `fence` sandbox using the `code` template (`copilot-fenced`). Fence provides:

- Network filtering via deny-by-default proxy (blocks cloud metadata APIs, restricts outbound destinations)
- Filesystem write restrictions (workspace + `/tmp`)
- Dangerous command blocking (`sudo`, etc.)
- Secret protection
- WSL auto-detection with `/init` interop support
- MCP servers configured via `~/.copilot/mcp-config.json` (managed by Nix)
- Skills from `ai/skills/` (auto-loaded)

### Authentication

#### GitHub

GitHub Copilot CLI authenticates via `gh auth login` (native flow). No PATs or sops-nix needed — GitHub Enterprise
licensing provides the AI models.

Commits to GitHub repositories are signed with an SSH key (`~/.ssh/id_ed25519_github`).

#### Azure DevOps

Git operations to Azure DevOps use SSH authentication with a password-less RSA key (`~/.ssh/id_rsa_azuredevops`).
Configure your SSH key in Azure DevOps under **User Settings → SSH Public Keys**.

The `url.insteadOf` rule in git config rewrites `https://dev.azure.com/` URLs to `git@ssh.dev.azure.com:v3/`
automatically. Azure DevOps commits are **not** signed.

### SSH Keys

Place these keys manually in `~/.ssh/`:

- `id_rsa_azuredevops` — Azure DevOps git push/pull via SSH (RSA, required by ADO)
- `id_ed25519_github` — GitHub commit signing (SSH signature)

GitHub authentication uses HTTPS via `gh auth login` — not SSH.

#### Fix permissions and line endings

When copying keys from Windows, they may have incorrect permissions and Windows-style line endings (`\r\n`). Fix both:

```bash
cd ~/.ssh
sed -i 's/\r$//' id_rsa_azuredevops id_ed25519_github
chmod 600 id_rsa_azuredevops id_ed25519_github
```

### Environment variables

The jailed Copilot CLI forwards these environment variables from the host shell:

- `GH_TOKEN` — GitHub OAuth token (used for git push operations inside the jail)
- `AZURE_DEVOPS_ORG` — your Azure DevOps organization name
- `AZURE_DEVOPS_PAT` — your raw Azure DevOps Personal Access Token

To make them survive shell restarts and reboots in fish, set them as universal exported variables:

```fish
set -Ux GH_TOKEN (gh auth token)
set -Ux AZURE_DEVOPS_ORG your-org
set -Ux AZURE_DEVOPS_PAT your-pat
```

The `copilot-fenced` wrapper sets SSL certificate paths and converts `--debug` to `--log-level debug`. Environment
variables (`GH_TOKEN`, `AZURE_DEVOPS_ORG`, `AZURE_DEVOPS_PAT`) are inherited by the fence sandbox. The wrapper also
converts `AZURE_DEVOPS_PAT` into the `PERSONAL_ACCESS_TOKEN` format expected by `azure-devops-mcp` by base64-encoding
`copilot:<your-pat>`. The `copilot` prefix is a required non-empty placeholder username; Azure DevOps ignores it and
uses only the PAT portion for authentication.

After rebuilding, the generated `~/.copilot/mcp-config.json` will contain an `azure-devops` MCP entry that launches the
server through the in-jail `copilot-azure-devops-mcp` wrapper.

## VS Code Remote WSL

The `nixos-vscode-server` module is enabled with FHS support. It uses patchelf to fix downloaded VS Code server binaries
and provides an FHS-compatible environment for extension native modules.

### Setup

1. Install the [Remote - WSL](https://marketplace.visualstudio.com/items?itemName=ms-vscode-remote.remote-wsl) extension
   in VS Code on Windows.

1. After the first rebuild, enable the auto-fix systemd user service:

   ```bash
   systemctl --user enable auto-fix-vscode-server.service
   ```

1. Open a WSL folder in VS Code — the server will be automatically downloaded and patched.

## JetBrains Remote Development

JetBrains Rider connects from Windows via SSH using JetBrains Gateway. The server-side tooling includes:

- **OpenSSH server** with `AllowTcpForwarding yes` for Gateway connections
- **JetBrains Rider** (unstable) with the `rider-remote-dev-server` wrapper
- **JetBrains JDK** for the JBR runtime
- **Expanded nix-ld libraries** for JetBrains backend compatibility

### Setup

1. Place your SSH public key in `~/.ssh/authorized_keys` on the WSL instance.
1. Install [JetBrains Gateway](https://www.jetbrains.com/remote-development/gateway/) on Windows.
1. In Gateway, connect to `jonatan@localhost` (or the WSL IP) via SSH.
1. Select Rider as the IDE — Gateway will detect the `rider-remote-dev-server` binary.

> **Note:** The auto-download path (`~/.cache/JetBrains/RemoteDev/`) works with nix-ld providing the dynamic linker. The
> nixpkgs `jetbrains.rider` package includes a patch that sets `REMOTE_DEV_SERVER_USE_SELF_CONTAINED_LIBS=0`.

## Other MCP Servers

```json
{
  "mcpServers": {
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
        "playwright-mcp",
        "--headless",
        "--no-sandbox"
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
