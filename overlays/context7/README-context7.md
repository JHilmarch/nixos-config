Context7 overlay

This overlay packages the Context7 MCP (https://github.com/upstash/context7) using Nixpkgs' buildNpmPackage.

Build targets

- Package: .#context7 (also the default package)

Quick build

- nix build .#context7
- Run the tool from the result:
  - ./result/bin/context7 --help

How version pinning works

- Source is fetched from GitHub by tag (rev = "v<version>") and pinned with a content hash (src.hash).
- npm dependencies are fetched by buildNpmPackage using npmDepsHash. This must match the dependencies resolved by the
  package-lock.json used during the build.
- This overlay vendors a package-lock.json alongside default.nix and copies it in postPatch, so builds are stable and
  reproducible.

Updating to a new upstream version

1. Bump version and src.rev in overlays/context7/default.nix to the new tag (e.g., v1.0.18).
1. Update the src.hash for the new tag:
   - Temporarily set a fake src.hash, e.g. sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=
   - Run nix build .#context7 (or nix build .#packages.x86_64-linux.context7)
   - Copy the wanted hash from the error into src.hash.
1. Refresh the vendored lockfile (only needed if upstream dependencies are changed or there is no package-lock.json in
   the repo):
   - Clone the upstream tag locally (outside Nix):
     - git clone https://github.com/upstash/context7 -b v<new-version> /tmp/context7
     - cd /tmp/context7
     - npm install --ignore-scripts
     - Verify package-lock.json exists
   - Copy /tmp/context7/package-lock.json to overlays/context7/package-lock.json
1. Reset npmDepsHash to a fake value to prompt Nix to print the correct one:
   - In overlays/context7/default.nix set: npmDepsHash = super.lib.fakeHash;
   - Run nix build .#context7
   - Copy the wanted: sha256-…= from the error into npmDepsHash.
1. Build again to verify it’s clean:
   - nix build .#context7

Common errors and fixes

- ERROR: The package-lock.json file does not exist!
  - Ensure overlays/context7/package-lock.json exists; the overlay copies it in postPatch.
- hash mismatch in fixed-output derivation …-npm-deps.drv
  - Set npmDepsHash to super.lib.fakeHash, run a build, and paste the wanted value into npmDepsHash.
- Fetcher hash mismatch for src
  - Set a temporary fake src.hash, run a build, and paste the wanted hash into src.hash.

Validating the flake/system after changes

- After changing any .nix files, it’s recommended to validate:
  - nix flake check
  - sudo nixos-rebuild test --flake .

Conventional commit suggestion (for when you commit)

- feat(context7): bump to vX.Y.Z and pin npmDepsHash

Notes

- If upstream switches package manager (e.g., pnpm/yarn/bun), we may need to adjust the builder or vendor the
  appropriate lockfile via postPatch.
