# OpenChamber

This package provides [OpenChamber](https://github.com/openchamber/openchamber) — a desktop and web interface for the
OpenCode AI agent. Built from upstream GitHub releases via `buildNpmPackage`.

## Build targets

- Package: `.#openchamber` (or `.#packages.x86_64-linux.openchamber` for full)

## Usage

This package is consumed by the system module at
[`modules/openchamber/default.nix`](../../modules/openchamber/default.nix), not invoked directly. Enable it on a host
via:

```nix
services.openchamber = {
  enable = true;
  uiPasswordFile = "/run/secrets/openchamber_ui_password";
  # port = 3000;            # OpenChamber web UI
  # openCodePort = 4095;    # local opencode server
  # bindAddress = "0.0.0.0"; # LAN-exposed by default
  # openFirewall = true;
};
```

The module wires up two systemd **user** services under `home-manager.users.<username>`:

- `opencode.service` — runs the jail-nix opencode wrapper in server mode on `openCodePort`
- `openchamber.service` — runs `openchamber serve` against that opencode server, reading the UI password from
  `uiPasswordFile` via the `OPENCHAMBER_UI_PASSWORD` env var

Concrete config (SOPS wiring) lives in [`modules/openchamber/sops.nix`](../../modules/openchamber/sops.nix). Currently
enabled on `orion` and `p51`.

### Direct CLI (debugging only)

The package also exposes the `openchamber` binary for ad-hoc debugging, but normal use is via the systemd unit:

```fish
openchamber --help
openchamber serve --port 3000 --host 127.0.0.1 --foreground
```

Do **not** use the bundled `openchamber update` command — on NixOS the package is rebuilt from this flake, so
self-update would diverge the running binary from the declarative system.

## Update

```fish
fish tools/update-packages/update-packages.fish update openchamber
```

Or via the `/update-packages` skill.

### Manual fallback

The build uses a **vendored `package-lock.json`** at `packages/openchamber/package-lock.json` because upstream does not
ship a workspace-aware lockfile matching our build shape. If an update fails during dependency resolution after bumping
the version, regenerate the lockfile from the new upstream tag and retry:

```fish
set -l tag v1.13.7
curl -fsSL "https://github.com/openchamber/openchamber/archive/refs/tags/$tag.tar.gz" | tar -xz
cd "openchamber-$tag"
npm install --package-lock-only --workspaces=false
cp package-lock.json ../packages/openchamber/package-lock.json
```

Then re-run the updater.

## Package details

- **Homepage**: https://github.com/openchamber/openchamber
- **License**: MIT
- **Platforms**: All (Linux, macOS)
- **Runtime**: Node.js 24, libvips (global, via `SHARP_FORCE_GLOBAL_LIBVIPS=true`)
