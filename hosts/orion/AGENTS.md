# hosts/orion/AGENTS.md

Desktop host: GNOME, NVIDIA, LUKS+FIDO2, YubiKey, dual boot with Windows.

## Structure

```
orion/
├── configuration.nix     # 382 lines. Imports 15 system modules, templates/desktop.nix, overlays
├── home.nix              # 182 lines. Imports 12 HM modules, package lists (stable/unstable/llm-agents)
├── modules/              # Orion-specific system modules
│   ├── sops.nix          # SOPS secret definitions (PATs, API keys, GH_TOKEN)
│   ├── claude.nix        # Configures HM modules.claude (preSetupScripts, runtimeInputs)
│   ├── opencode.nix      # Configures HM modules.opencode (settings, MCP, LSP)
│   ├── docker.nix        # Docker with btrfs storage, rootless, GDM session guard
│   ├── openrazer.nix     # OpenRazer with GDM session guard
│   ├── file.nix          # GTK bookmarks file deployment
│   └── dconf/            # GNOME dconf settings (391 lines)
│       ├── default.nix   # Workspace count, keybindings, tiling shell extension
│       └── tilingshell-layouts.json
├── boot-initrd-scripts/  # 7 scripts for LUKS+FIDO2 YubiKey unlock during initrd
│   ├── init-shell.sh     # Shell environment for initrd
│   ├── attach-yubikey.sh # Attach YubiKey to initrd
│   ├── detach-yubikey.sh
│   ├── bind-yubikey.sh   # Bind YubiKey to LUKS
│   ├── unbind-yubikey.sh
│   ├── detect-yubikey.sh
│   └── unlock-luks.sh    # Unlock LUKS with FIDO2 challenge
├── images/               # Custom boot splash image
├── README-orion.md       # Detailed setup docs (SOPS, YubiKey, NVIDIA, dual boot)
└── aspnetcore-https-development.pem  # ASP.NET dev cert (non-secret)
```

## Where to Look

- **Add a system package** → `home.nix` — group by source: `home.packages`, `pkgs.unstable`, `inputs.llm-agents`
- **Add a GNOME setting** → `modules/dconf/default.nix` — dconf paths under `org.gnome.*`
- **Add a SOPS secret** → `modules/sops.nix` — add to `sops.secrets`, reference in wrapper scripts
- **Configure Claude** → `modules/claude.nix` — sets preSetupScripts, runtimeInputs on HM module
- **Configure OpenCode** → `modules/opencode.nix` — sets MCP servers, LSP config, runtimeInputs
- **Change boot behavior** → `boot-initrd-scripts/` — injected via `boot.initrd.systemd.initrdBin`
- **Fix NVIDIA issues** → `configuration.nix` — `services.xserver.videoDrivers`, nvidia package
- **Change disk encryption** → `configuration.nix` — LUKS+FIDO2 config in `boot.initrd.luks`

## Conventions

- `configuration.nix` imports shared modules via `"${self}/modules/<path>"` and local modules via `./modules/<name>.nix`
- Host-specific HM module config done in `modules/<agent>.nix` using `home-manager.users.${username}`
- Package lists in `home.nix` separated by source: stable, unstable, llm-agents
- dconf is a large file (391 lines) — use `dconf watch /` to find settings paths
- Initrd scripts are POSIX sh (not bash) — run in minimal initrd environment

## Anti-Patterns

- **NEVER** edit `secrets/orion/secrets.yml` — SOPS-encrypted
- **NEVER** hardcode PATs in configuration — use `config.sops.secrets.<name>.path`
- **NEVER** modify boot scripts without testing — LUKS lockout risk
