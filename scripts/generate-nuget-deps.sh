#!/usr/bin/env bash
# Generate overlays/<pkg>/deps.json with pinned NuGet deps for a .NET tool
# Resolves dependencies via 'dotnet tool install' (no fallback to nuget)
# Usage:
#   nix-shell -p dotnet-sdk unzip jq nix --run \
#     "bash scripts/generate-nuget-deps.sh [--ensure-sibling <LeftId>:<RightId>]... <PackageId> [Version] [OutputPath]"
# Options:
#   --ensure-sibling L:R   Ensure package R is included for every version of L
#                          discovered in the dependency graph. This is useful
#                          for RID-specific siblings not pulled into the tool
#                          store (repeatable).
# Examples:
#   nix-shell -p dotnet-sdk unzip jq nix --run \
#     "bash scripts/generate-nuget-deps.sh --ensure-sibling azure.mcp:azure.mcp.linux-x64 Azure.Mcp 0.8.6 overlays/azure-mcp-server/deps.json"
#   nix-shell -p dotnet-sdk unzip jq nix --run \
#     "bash scripts/generate-nuget-deps.sh NuGet.Mcp.Server 1.0.0 overlays/nuget-mcp-server/deps.json"

set -euo pipefail

require_cmd() {
  if ! command -v "$1" >/dev/null 2>&1; then
    printf "ERROR: '%s' not found in PATH\n" "$1" >&2
    exit 1
  fi
}

# Parse flags and positional args
ENSURE_SIBLINGS=()
while [[ $# -gt 0 ]]; do
  case "$1" in
    --ensure-sibling)
      if [[ $# -lt 2 ]]; then
        echo "ERROR: --ensure-sibling requires L:R value" >&2; exit 1;
      fi
      ENSURE_SIBLINGS+=("$2")
      shift 2
      ;;
    --help|-h)
      sed -n '1,20p' "$0" | sed 's/^# \{0,1\}//' >&2
      exit 0
      ;;
    --*)
      echo "ERROR: Unknown option: $1" >&2; exit 1
      ;;
    *)
      break
      ;;
  esac
done

# Require PackageId; OutputPath optional (defaults to ./deps.json); Version optional
if [[ $# -lt 1 ]]; then
  echo "Usage: $0 [--ensure-sibling L:R]... <PackageId> [Version] [OutputPath]" >&2
  exit 1
fi
PKG="$1"; shift
VER=""
OUT="deps.json"
if [[ $# -ge 1 ]]; then
  if [[ $# -eq 1 ]]; then
    # If the next arg looks like a path (contains '/' or ends with .json), treat it as OutputPath
    if [[ "$1" == */* || "$1" == *.json ]]; then
      OUT="$1"
    else
      VER="$1"
    fi
  else
    VER="$1"; OUT="$2"
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

# De-duplicate by (name,version)
json=$(printf '%s\n' "${entries[@]}" | jq -s 'unique_by(.name + ":" + .version)')

# Ensure sibling packages as requested via --ensure-sibling L:R
if [[ ${#ENSURE_SIBLINGS[@]} -gt 0 ]]; then
  for pair in "${ENSURE_SIBLINGS[@]}"; do
    L="${pair%%:*}"; R="${pair#*:}"
    if [[ -z "$L" || -z "$R" || "$L" == "$pair" ]]; then
      printf 'WARN: invalid --ensure-sibling value: %s (expected L:R)\n' "$pair" >&2
      continue
    fi
    l_lc=$(echo "$L" | tr '[:upper:]' '[:lower:]')
    # All unique versions of L present in json
    mapfile -t vers < <(printf '%s\n' "$json" | jq -r --arg l "$l_lc" '[.[] | select((.name|ascii_downcase)==$l) | .version] | unique[]?')
    if [[ ${#vers[@]} -eq 0 ]]; then
      continue
    fi
    r_lc=$(echo "$R" | tr '[:upper:]' '[:lower:]')
    for v in "${vers[@]}"; do
      # Skip if R@v already present
      if printf '%s\n' "$json" | jq -e --arg r "$r_lc" --arg v "$v" 'any(.[]; ((.name|ascii_downcase)==$r) and .version==$v)' >/dev/null; then
        continue
      fi
      url="https://www.nuget.org/api/v2/package/${R}/${v}"
      if b32=$(nix-prefetch-url --type sha256 "$url" 2>/dev/null); then
        json=$(printf '%s\n' "$json" | jq --arg name "$R" --arg v "$v" --arg s "$b32" '. + [{"name":$name,"version":$v,"sha256":$s}] | unique_by(.name + ":" + .version)')
      else
        printf 'WARN: failed to prefetch %s\n' "$url" >&2
      fi
    done
  done
fi

# Write JSON
mkdir -p "$(dirname "$OUT")"
printf '%s\n' "$json" > "$OUT"

printf 'Wrote %s with %s entries.\n' "$OUT" "$(jq 'length' "$OUT")"
