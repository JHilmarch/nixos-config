# modules/AGENTS.md

System-level NixOS modules. Two patterns: pure config and option-based.

## Structure

```
modules/
├── defaults.nix          # Base: timezone (Europe/Stockholm), experimental Nix features
├── context7/
│   └── sops-wrapper.nix  # Bridges SOPS secret to context7-mcp binary (crosses system↔HM)
├── acme-wildcard/
│   └── default.nix       # services.acmeWildcard.enable — Cloudflare DNS-01 *.fileshare.se wildcard cert (+ nginx→acme group)
├── nginx-ingress/
│   └── default.nix       # services.nginxIngress.{enable,virtualHosts.<fqdn>.{proxyPass,external}} — nginx recommended* settings, 80/443 firewall, *.fileshare.se reverse-proxy vhost helper; vhosts are LAN-only (RFC1918 allow + deny-all) unless external=true (pairs with acmeWildcard)
├── nfs/
│   ├── default.nix       # Options: nfs.{enable, host, ip, shares, port} → generates fileSystems
│   └── fileshare.nix     # Concrete config for home NAS (fileshare.local)
├── security-overrides/
│   └── default.nix       # security.overrides.{enable,aggressive} — overlay pulling vim/sqlite/libmicrohttpd/libcap/fzf/fish/dash from nixpkgs-unstable to close CVEs not yet backported to nixos-26.05; `aggressive=true` also overrides giflib (5→6) and graphite2
├── spotify/
│   └── firewall.nix      # services.spotifyFirewall.enable — TCP/UDP 5353, 57621
├── ssh-host-key-persistence/
│   └── default.nix       # services.sshHostKeyPersistence.enable — persists SSH host ed25519 key on /persist (survives LXC destroy/recreate)
├── yubikey-usbip/
│   └── default.nix       # services.yubikeyUsbip.enable — usbusers group, udev hidraw rule, usbip + wrapped scripts (from scripts/yubikey-usbip/)
└── systemd/
    ├── no-sleep.nix      # services.systemdNoSleep.enable — disables suspend/hibernate
    ├── wake-on-lan.nix   # services.systemdWakeOnLan.{enable, interface} — ethtool WoL
    ├── power-profile.nix # services.systemdPowerProfile.enable — performance on boot
    ├── flatpak.nix       # services.systemdFlatpak.enable — flathub remote setup
    ├── firefox.nix       # services.systemdFirefox.enable — Flatpak Firefox (depends on flatpak)
    └── nvidia-coolbits.nix # services.systemdNvidiaCoolbits.{enable, value} — X11 config
```

## Where to Look

- **Add a new system module** → create `modules/<name>/default.nix` — use `mkEnableOption` pattern
- **Add a concrete config consuming a reusable module** → `nfs/fileshare.nix` as template — imports `default.nix` and
  sets host-agnostic concrete values
- **Add systemd oneshot service** → `systemd/` existing files as template — `services.systemd<CamelCase>.enable`
- **Add a systemd USER service from a system module** → `home-manager.users.${username}` + `systemd.user.services`
- **Add NFS share** → `nfs/fileshare.nix` — add to `nfs.shares` list
- **Bridge SOPS to a CLI tool** → `context7/sops-wrapper.nix` as template — crosses system↔HM boundary

## Module Patterns

### Option-Based (standard pattern)

```nix
{ config, lib, ... }:
with lib; let cfg = config.services.<camelCase>;
in {
  options.services.<camelCase> = { enable = mkEnableOption "..."; };
  config = mkIf cfg.enable { ... };
};
```

Used by: nfs, spotify, systemd/\*

### Pure Config (no options)

```nix
{ pkgs, inputs, ... }: { ... }
```

Used by: defaults.nix, context7/sops-wrapper.nix

### Option Naming

System modules: `services.<camelCase>` (e.g., `systemdNoSleep`, `spotifyFirewall`) Exception: `nfs.*` uses top-level
namespace (submodule with shares)

## Conventions

- Module files: `default.nix` in subdirectory (e.g., `nfs/default.nix`)
- Assertions for prerequisites (e.g., firewall enabled, nvidia driver present)
- Flatpak-dependent modules use `after = ["systemdFlatpak.service"]` + `wants`
- `nfs/default.nix` generates: fileSystems entries, networking.hosts, firewall rules, tmpfiles rules

## Anti-Patterns

- **NEVER** use `services.<kebab-case>` for option names — use camelCase
- **NEVER** create modules that depend on other modules without assertions
- **NEVER** import `nfs/fileshare.nix` directly — import `nfs/default.nix` and set options
