# NixOS on WSL CAB

[Docs](https://nix-community.github.io/NixOS-WSL/)

## Build

To build the WSL tarball with Nix:

```bash
cd ~
sudo nix run /home/jonatan/code/nixos-config/#nixosConfigurations.wsl-cab.config.system.build.tarballBuilder
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

## GitHub authentication

The wrapped GitHub MCP Server uses the access token from GitHub CLI to authenticate. Login with `gh auth login`.

## Context7 Authentication

The Context7 MCP server provides up-to-date code documentation. To use it, set `CONTEXT7_TOKEN` as a User environment
variable in Windows.

### Create a PowerShell wrapper script

1. Save the wrapper script from the gist:
   [context7-mcp-wsl-wrapper.ps1](https://gist.github.com/JHilmarch/1968c745d36e265a4ef75bb5f6d2dc0f)
1. Save the wrapper to `C:\Users\%USERNAME%\.copilot\context7-mcp-wsl-wrapper.ps1`

```powershell
$token = [Environment]::GetEnvironmentVariable("CONTEXT7_TOKEN", "User")

if (-not $token) {
    $token = [Environment]::GetEnvironmentVariable("CONTEXT7_TOKEN", "Machine")
}

if (-not $token) {
    $token = $env:CONTEXT7_TOKEN
}

if (-not $token) {
    Write-Error "CONTEXT7_TOKEN not found in User, Machine, or current environment" -ErrorAction Stop
    exit 1
}

$process = Start-Process -FilePath "wsl.exe" -ArgumentList "-d", "NixOS", "--", "context7-mcp", "--api-key", $token -NoNewWindow -PassThru -Wait
exit $process.ExitCode
```

*context7-mcp-wsl-wrapper.ps1*

### Set CONTEXT7_TOKEN environment variable

Open PowerShell and run:

```powershell
[System.Environment]::SetEnvironmentVariable('CONTEXT7_TOKEN', 'your-token-here', 'User')
```

**Notes:**

- User-level variables are stored in `HKEY_CURRENT_USER\Environment`
- To set system-wide (all users): use `'Machine'` instead of `'User'` (requires admin)
- You can also set variables via Windows Settings GUI: Settings > System > About > Advanced system settings >
  Environment Variables
- The variable is immediately available to WSL processes. No restart needed.

### Configure GitHub Copilot CLI MCP

Add the following to your GitHub Copilot CLI MCP configuration (`mcpServers` section):

```json
{
  "mcpServers": {
    "context7": {
      "command": "pwsh",
      "args": [
        "-ExecutionPolicy",
        "Bypass",
        "-File",
        "C:\\Users\\<USERNAME>\\.copilot\\context7-mcp-wsl-wrapper.ps1"
      ]
    }
  }
}
```

This configuration tells GitHub Copilot CLI to:

1. Use `pwsh` to run the PowerShell wrapper script
1. Script handles token retrieval and passes `--api-key` to `context7-mcp` automatically

## SSH Key Setup for Secret Decryption

The `decrypt-secrets` systemd service decrypts secrets using your SSH key. The encrypted secrets file
(`secrets/wsl-cab/secrets.yml`) is copied into the tarball at `/etc/nixos/secrets/wsl-cab/secrets.yml` during build.

The service starts automatically with the user session after WSL reboot. Decrypted secrets are stored in
`/run/user/1000/secrets/` and persist as long as the WSL instance is running.

### 1. Copy your SSH private key

Copy your age-compatible SSH private key to the default location:

```bash
cp /path/to/your/key ~/.ssh/id_ed25519
```

### 2. Set correct permissions

```bash
chmod 600 ~/.ssh/id_ed25519
```

### 3. Convert line endings (if copied from Windows)

If you copied the key from Windows, convert CRLF to LF:

```bash
sed -i 's/\r$//' ~/.ssh/id_ed25519
```

### 4. Verify the service (optional)

The service starts automatically after WSL reboot. To check if it's running or manually restart it:

```bash
# Check service status
systemctl --user status decrypt-secrets.service

# Manually restart if needed
systemctl --user restart decrypt-secrets.service
```

### 5. Verify decrypted secrets

Decrypted secrets are stored in `$XDG_RUNTIME_DIR/secrets/` (usually `/run/user/1000/secrets/`):

```bash
ls -la /run/user/(id -u)/secrets/
```

## Other MCP Servers

```json
{
  "mcpServers": {
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
