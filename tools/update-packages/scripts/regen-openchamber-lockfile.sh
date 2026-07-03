#!/usr/bin/env bash
# Regenerate packages/openchamber/package-lock.json from an upstream tag.
# Called by tools/update-packages/packages/openchamber.fish on every bump.
# See packages/openchamber/README.md "Vendored lockfile behavior" for the flow.
#
# Requires on PATH: curl, gunzip, tar, node, npm.
#
# Usage:
#   bash tools/update-packages/scripts/regen-openchamber-lockfile.sh <version> <output-lockfile>

set -euo pipefail

if [[ $# -lt 2 ]]; then
  echo "Usage: $0 <version> <output-lockfile>" >&2
  exit 1
fi

version="$1"
output_lockfile="$2"
owner_repo="openchamber/openchamber"

# Absolutize before the cd below, so the final cp lands in the repo, not the temp dir.
case "$output_lockfile" in
  /*) : ;;
  *) output_lockfile="$PWD/$output_lockfile" ;;
esac

require_cmd() {
  if ! command -v "$1" >/dev/null 2>&1; then
    printf "ERROR: '%s' not found in PATH.\n" "$1" >&2
    printf "  Inside the opencode jail: check home-modules/opencode/default.nix add-pkg-deps.\n" >&2
    printf "  On a host: add the missing package to environment.systemPackages.\n" >&2
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

# Version the new tag requires; asserted against the regenerated lockfile below.
sdk_want="$(node -p 'JSON.parse(require("fs").readFileSync("packages/web/package.json","utf8")).dependencies["@opencode-ai/sdk"]')"
printf "  -> Tag v%s requires @opencode-ai/sdk %s\n" "$version" "$sdk_want" >&2

# Drop shipped resolution priors so npm re-resolves fresh instead of "up to date".
rm -rf node_modules packages/*/node_modules
rm -f package-lock.json npm-shrinkwrap.json yarn.lock bun.lock bun.lockb .npmrc

# Apply the workspaces override the Nix build does (see packages/openchamber/default.nix).
node -e '
  const fs = require("fs");
  const p = JSON.parse(fs.readFileSync("package.json", "utf8"));
  p.workspaces = ["packages/ui", "packages/web"];
  fs.writeFileSync("package.json", JSON.stringify(p, null, 2) + "\n");
'

# Fresh empty cache + forced online metadata so a stale ~/.npm packument can't pin an old version.
printf "  -> Running npm install --package-lock-only (fresh cache, online)...\n" >&2
npm install \
  --package-lock-only \
  --lockfile-version=3 \
  --ignore-scripts --no-audit --no-fund \
  --cache="$(mktemp -d)" \
  --prefer-online \
  --registry=https://registry.npmjs.org/

# Abort if the fresh resolution didn't pin the required sdk version.
sdk_got="$(node -p 'JSON.parse(require("fs").readFileSync("package-lock.json","utf8")).packages["node_modules/@opencode-ai/sdk"].version')"
if [[ "$sdk_got" != "$sdk_want" ]]; then
  printf "ERROR: regenerated lockfile pins @opencode-ai/sdk %s, but tag v%s requires %s.\n" \
    "$sdk_got" "$version" "$sdk_want" >&2
  exit 1
fi

mkdir -p "$(dirname "$output_lockfile")"
cp "$tmp/openchamber-$version/package-lock.json" "$output_lockfile"

# Verify the pin landed at the final repo path, not just inside the temp dir.
sdk_final="$(node -p 'JSON.parse(require("fs").readFileSync(process.argv[1],"utf8")).packages["node_modules/@opencode-ai/sdk"].version' "$output_lockfile")"
if [[ "$sdk_final" != "$sdk_want" ]]; then
  printf "ERROR: %s pins @opencode-ai/sdk %s, want %s (lockfile did not land at repo path).\n" \
    "$output_lockfile" "$sdk_final" "$sdk_want" >&2
  exit 1
fi
printf "  -> Vendored lockfile written to %s (sdk %s)\n" "$output_lockfile" "$sdk_final" >&2
