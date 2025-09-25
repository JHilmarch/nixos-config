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
    }
  }
}
```
