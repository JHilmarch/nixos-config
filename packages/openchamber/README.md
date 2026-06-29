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

### Vendored lockfile behavior

The build uses a **vendored `package-lock.json`** at `packages/openchamber/package-lock.json` because upstream's root
`package.json` declares `workspaces = ["packages/*"]`, but this package only builds `packages/ui` and `packages/web`.
The lockfile **must** be generated with that same restricted workspace set, otherwise `npm install` in the sandbox can
fail with `ENOTCACHED` for workspace-only deps (for example `@pierre/diffs` when the old lockfile still pins the wrong
beta version).

The updater now handles this automatically: if the version bump succeeds for the source hash but the `npmDepsHash`
extraction fails because the vendored lockfile is stale, `update_openchamber` regenerates the lockfile from the new tag
and retries.

If you need to run the regeneration helper directly, use:

```fish
nix shell nixpkgs#curl nixpkgs#cacert nixpkgs#gnutar nixpkgs#gzip nixpkgs#nodejs_24 -c bash \
  tools/update-packages/scripts/regen-openchamber-lockfile.sh 1.13.8 \
  packages/openchamber/package-lock.json
```

Then re-run the updater (it will recompute `npmDepsHash` and verify the build).

## Package details

- **Homepage**: https://github.com/openchamber/openchamber
- **License**: MIT
- **Platforms**: All (Linux, macOS)
- **Runtime**: Node.js 24, libvips (global, via `SHARP_FORCE_GLOBAL_LIBVIPS=true`)
