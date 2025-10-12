#!/usr/bin/env bash
# Generate overlays/<pkg>/deps.json with pinned NuGet deps for a .NET tool
# Resolves dependencies via 'dotnet tool install' (no fallback to nuget)
# Usage:
#   nix-shell -p dotnet-sdk unzip jq nix --run "bash scripts/generate-nuget-deps.sh <PackageId> [Version] [OutputPath]"
# Examples:
#   nix-shell -p dotnet-sdk unzip jq nix --run "bash scripts/generate-nuget-deps.sh Azure.Mcp 0.8.6 overlays/azure-mcp-server/deps.json"
#   nix-shell -p dotnet-sdk unzip jq nix --run "bash scripts/generate-nuget-deps.sh NuGet.Mcp.Server 1.0.0 overlays/nuget-mcp-server/deps.json"

set -euo pipefail

require_cmd() {
  if ! command -v "$1" >/dev/null 2>&1; then
    printf "ERROR: '%s' not found in PATH\n" "$1" >&2
    exit 1
  fi
}

# Require PackageId; OutputPath optional (defaults to ./deps.json); Version optional
if [[ $# -lt 1 ]]; then
  echo "Usage: $0 <PackageId> [Version] [OutputPath]" >&2
  exit 1
fi
PKG="$1"
VER=""
OUT="deps.json"
if [[ $# -ge 2 ]]; then
  if [[ $# -eq 2 ]]; then
    # If the second arg looks like a path (contains '/' or ends with .json), treat it as OutputPath
    if [[ "$2" == */* || "$2" == *.json ]]; then
      OUT="$2"
    else
      VER="$2"
    fi
  else
    VER="$2"
    OUT="$3"
  fi
fi
pkg_lc=$(echo "$PKG" | tr '[:upper:]' '[:lower:]' | tr '.' '-')
TMP="$(mktemp -d)"

require_cmd dotnet
require_cmd unzip
require_cmd jq
require_cmd nix
require_cmd nix-prefetch-url

# Use dotnet tool installation to resolve dependencies into a local .store
TOOLS_DIR="$TMP/tools"
mkdir -p "$TOOLS_DIR"
# Attempt install; use nuget.org as source
if [[ -n "$VER" ]]; then
  DOTNET_CLI_HOME="$TMP" dotnet tool install "$PKG" --version "$VER" \
    --tool-path "$TOOLS_DIR" --add-source https://api.nuget.org/v3/index.json 1>/dev/null || DOTNET_TOOL_FAILED=1
else
  DOTNET_CLI_HOME="$TMP" dotnet tool install "$PKG" \
    --tool-path "$TOOLS_DIR" --add-source https://api.nuget.org/v3/index.json 1>/dev/null || DOTNET_TOOL_FAILED=1
fi

entries=()

STORE_DIR="$TOOLS_DIR/.store"
if [[ ! -d "$STORE_DIR" ]]; then
  printf 'ERROR: dotnet tool install did not produce .store at %s\n' "$STORE_DIR" >&2
  exit 1
fi

# Iterate packages in .store (id/version pairs)
while IFS= read -r -d '' dir; do
  # Expect .../.store/<id>/<version>/...
  ver_dir="$(basename "$dir")"
  id_dir="$(basename "$(dirname "$dir")")"

  # Validate via nuspec if present
  nuspec_file="$(find "$dir" -maxdepth 2 -type f -name '*.nuspec' | head -n1 || true)"
  if [[ -f "$nuspec_file" ]]; then
    nuspec=$(cat "$nuspec_file")
    id=$(printf '%s' "$nuspec" | sed -n 's:.*<id>\([^<]*\)</id>.*:\1:p' | head -n1)
    ver=$(printf '%s' "$nuspec" | sed -n 's:.*<version>\([^<]*\)</version>.*:\1:p' | head -n1)
  else
    id="$id_dir"; ver="$ver_dir"
  fi

  if [[ -z "${id:-}" || -z "${ver:-}" ]]; then
    printf 'WARN: could not determine id/version for %s\n' "$dir" >&2
    continue
  fi

  # Compute SRI sha256 by prefetching the package from nuget v2 API
  url="https://www.nuget.org/api/v2/package/${id}/${ver}"
  if b32=$(nix-prefetch-url --type sha256 "$url" 2>/dev/null); then
    :
  else
    printf 'WARN: failed to prefetch %s\n' "$url" >&2
    continue
  fi

  # Store legacy base32 hash; fetchurl accepts base32 in sha256 attr
  entries+=("{\"name\":\"$id\",\"version\":\"$ver\",\"sha256\":\"$b32\"}")

done < <(find "$STORE_DIR" -mindepth 2 -maxdepth 2 -type d -print0 | sort -z)

# De-duplicate by (name,version) and write JSON
json=$(printf '%s\n' "${entries[@]}" | jq -s 'unique_by(.name + ":" + .version)')
mkdir -p "$(dirname "$OUT")"
printf '%s\n' "$json" > "$OUT"

printf 'Wrote %s with %s entries.\n' "$OUT" "$(jq 'length' "$OUT")"
