# Context7 overlay

This overlay packages the Context7 MCP (https://github.com/upstash/context7) using Nixpkgs' buildNpmPackage.

## Build targets

- Package: .#context7 (also the default package)

## Quick start

- nix build .#context7
- Run the tool from the result:
  - ./result/bin/context7 --help

## How version pinning works

- Source is fetched from GitHub by tag (rev = "v<version>") and pinned with a content hash (src.hash).
- npm dependencies are fetched by _buildNpmPackage_ using _npmDepsHash_. This must match the dependencies resolved by
  the `package-lock.json` used during the build.
- This overlay vendors a `package-lock.json` alongside `default.nix` and copies it in postPatch, so builds are stable
  and reproducible.

Updating to a new upstream version

1. Bump version and src.rev in _overlays/context7/default.nix_ to the new tag (e.g., v1.0.18).
1. Update the src.hash for the new tag:
   - Temporarily set a fake src.hash, e.g. sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=
   - Run `nix build .#context7` (or nix build .#packages.x86_64-linux.context7)
   - Copy the wanted hash from the error into src.hash.
1. Refresh the vendored lockfile (only needed if upstream dependencies are changed or there is no `package-lock.json` in
   the repo):
   - Clone the upstream tag locally (outside Nix):
     - git clone https://github.com/upstash/context7 -b v<new-version> /tmp/context7
     - cd /tmp/context7
     - npm install --ignore-scripts
     - Verify package-lock.json exists
   - Copy _/tmp/context7/package-lock.json_ to _overlays/context7/package-lock.json_
1. Reset npmDepsHash to a fake value to prompt Nix to print the correct one:
   - In _overlays/context7/default.nix_ set: `npmDepsHash = super.lib.fakeHash;`
   - Run `nix build .#context7`
   - Copy the wanted: sha256-…= from the error into npmDepsHash.
1. Build again to verify it’s clean:
   - `nix build .#context7`

Conventional commit suggestion (for when you commit)

- feat(context7): bump to vX.Y.Z and pin npmDepsHash

Notes

- If upstream switches package manager (e.g., pnpm/yarn/bun), we may need to adjust the builder or vendor the
  appropriate lockfile via postPatch.
