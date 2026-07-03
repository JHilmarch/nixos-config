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

- `opencode.service` — runs the nono-wrapped opencode in server mode on `openCodePort`
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

On every version bump `update_openchamber` runs these steps in order:

1. Bump `version` and fix the source `hash` in `default.nix`.
1. **Regenerate the vendored lockfile** from the new tag via `regen-openchamber-lockfile.sh` (see below).
1. **Recompute `npmDepsHash`** with `prefetch-npm-deps` — the exact tool `buildNpmPackage`'s `fetchNpmDeps` uses, so the
   hash always matches the current lockfile. It's resolved through the flake's own locked `nixpkgs` input, so it needs
   no flake registry.
1. Verify the package builds.

`regen-openchamber-lockfile.sh` downloads the tag tarball into a temp dir, applies the same
`workspaces = ["packages/ui", "packages/web"]` override the Nix build applies, and runs
`npm install --package-lock-only`. To make that resolution deterministic it:

- deletes any resolution prior the tarball ships (`package-lock.json`/`.npmrc`/`yarn.lock`/`bun.lock*`), so npm can't
  report "up to date" against a stale lockfile;
- resolves against a **fresh empty cache** with `--prefer-online` and an explicit registry, so a stale `~/.npm`
  packument can't pin an old version;
- **asserts** the regenerated lockfile pins the `@opencode-ai/sdk` version the new tag requires — both in the temp dir
  and again at the final repo path — and aborts loudly if not, rather than letting a stale lockfile reach the Nix build
  and fail there with `ENOTCACHED`.

If you need to run the regeneration helper directly, use:

```fish
bash tools/update-packages/scripts/regen-openchamber-lockfile.sh 1.13.8 \
  packages/openchamber/package-lock.json
```

The helper needs `curl`, `gunzip`, `tar`, `node`, and `npm` on PATH. Inside the opencode sandbox these come from
`home-modules/opencode/default.nix`; on p51 they come from `environment.systemPackages` (plus whatever node/npm the user
env provides).

Then re-run the updater (it will recompute `npmDepsHash` and verify the build).

## Package details

- **Homepage**: https://github.com/openchamber/openchamber
- **License**: MIT
- **Platforms**: All (Linux, macOS)
- **Runtime**: Node.js 24, libvips (global, via `SHARP_FORCE_GLOBAL_LIBVIPS=true`)
