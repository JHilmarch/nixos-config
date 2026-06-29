#!/usr/bin/env bash
# Regenerate packages/openchamber/package-lock.json from an upstream tag.
#
# Called automatically by tools/update-packages/packages/openchamber.fish when
# a version bump fails the npmDepsHash build with a stale lockfile (i.e. upstream
# added/changed/removed deps and the vendored lockfile no longer matches).
#
# Mirrors the workspaces override the Nix build applies in
# packages/openchamber/default.nix:
#     packageJson.workspaces = ["packages/ui", "packages/web"];
#
# Usage:
#   nix shell nixpkgs#curl nixpkgs#cacert nixpkgs#gnutar nixpkgs#gzip nixpkgs#nodejs_24 -c bash \
#     tools/update-packages/scripts/regen-openchamber-lockfile.sh <version> <output-lockfile>
#
# Examples:
#   nix shell nixpkgs#curl nixpkgs#cacert nixpkgs#gnutar nixpkgs#gzip nixpkgs#nodejs_24 -c bash \
#     tools/update-packages/scripts/regen-openchamber-lockfile.sh 1.13.8 \
#     packages/openchamber/package-lock.json

set -euo pipefail

if [[ $# -lt 2 ]]; then
  echo "Usage: $0 <version> <output-lockfile>" >&2
  exit 1
fi

version="$1"
output_lockfile="$2"
owner_repo="openchamber/openchamber"

require_cmd() {
  if ! command -v "$1" >/dev/null 2>&1; then
    printf "ERROR: '%s' not found in PATH. Invoke via:\n  nix shell nixpkgs#curl nixpkgs#cacert nixpkgs#gnutar nixpkgs#gzip nixpkgs#nodejs_24 -c bash %s ...\n" "$1" "$0" >&2
    exit 1
  fi
}

require_cmd curl
require_cmd gunzip
require_cmd tar
require_cmd node
require_cmd npm

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

printf "  -> Downloading %s v%s source...\n" "$owner_repo" "$version" >&2
curl -fsSL -o "$tmp/src.tar.gz" "https://github.com/$owner_repo/archive/refs/tags/v$version.tar.gz"

cd "$tmp"
gunzip -c src.tar.gz > src.tar
tar -xf src.tar
cd "openchamber-$version"

# Apply the workspaces override the Nix build does (see packages/openchamber/default.nix).
node -e '
  const fs = require("fs");
  const p = JSON.parse(fs.readFileSync("package.json", "utf8"));
  p.workspaces = ["packages/ui", "packages/web"];
  fs.writeFileSync("package.json", JSON.stringify(p, null, 2) + "\n");
'

printf "  -> Running npm install --package-lock-only (ignoring postinstall scripts)...\n" >&2
npm install --package-lock-only --no-audit --no-fund --ignore-scripts

mkdir -p "$(dirname "$output_lockfile")"
cp "$tmp/openchamber-$version/package-lock.json" "$output_lockfile"
printf "  -> Vendored lockfile written to %s\n" "$output_lockfile" >&2
