#!/usr/bin/env bash
# Generate overlays/<pkg>/deps.json with pinned NuGet deps for a .NET project
# Resolves dependencies via 'dotnet restore' on a project file
# Automatically includes linux-x64 RID siblings for all packages
# Usage:
#   nix-shell -p dotnet-sdk jq nix --run \
#     "bash scripts/generate-nuget-deps-from-project.sh <ProjectPath> [OutputPath]"
#
# Examples:
#   nix-shell -p dotnet-sdk jq nix --run \
#     "bash scripts/generate-nuget-deps-from-project.sh \
#        /path/to/mcp-dotnet-samples/awesome-copilot/src/McpSamples.AwesomeCopilot.HybridApp \
#        overlays/awesome-copilot/deps.json"

set -euo pipefail

require_cmd() {
  if ! command -v "$1" >/dev/null 2>&1; then
    printf "ERROR: '%s' not found in PATH\n" "$1" >&2
    exit 1
  fi
}

# Parse args
if [[ $# -lt 1 ]]; then
  cat >&2 <<EOF
Usage: $0 <ProjectPath> [OutputPath]

Arguments:
  ProjectPath   Path to the .NET project directory or .csproj file
  OutputPath    Path to output deps.json (default: deps.json)

Examples:
  $0 /path/to/mcp-dotnet-samples/awesome-copilot/src/McpSamples.AwesomeCopilot.HybridApp overlays/awesome-copilot/deps.json
EOF
  exit 1
fi

PROJECT_PATH="$1"
OUT="${2:-deps.json}"

# If PROJECT_PATH is a directory, find the .csproj file
if [[ -d "$PROJECT_PATH" ]]; then
  CSproj=$(find "$PROJECT_PATH" -maxdepth 1 -name "*.csproj" | head -n1)
  if [[ -z "$CSproj" ]]; then
    printf "ERROR: No .csproj file found in %s\n" "$PROJECT_PATH" >&2
    exit 1
  fi
  PROJECT_PATH="$CSproj"
fi

if [[ ! -f "$PROJECT_PATH" ]]; then
  printf "ERROR: Project file not found: %s\n" "$PROJECT_PATH" >&2
  exit 1
fi

TMP="$(mktemp -d)"
PACKAGES_DIR="$TMP/packages"

require_cmd dotnet
require_cmd jq
require_cmd nix
require_cmd nix-prefetch-url

printf "Restoring NuGet packages for %s...\n" "$PROJECT_PATH"

# Restore packages to a local directory
mkdir -p "$PACKAGES_DIR"
dotnet restore "$PROJECT_PATH" --packages "$PACKAGES_DIR" --verbosity quiet >/dev/null

if [[ ! -d "$PACKAGES_DIR" ]]; then
  printf "ERROR: dotnet restore did not produce packages directory at %s\n" "$PACKAGES_DIR" >&2
  exit 1
fi

printf "Extracting package information and prefetching...\n"

entries=()
count=0
total=0

# Count total packages first
total=$(find "$PACKAGES_DIR" -mindepth 2 -maxdepth 2 -type d | wc -l)

# Iterate packages in the packages directory (id/version pairs)
while IFS= read -r -d '' dir; do
  # Expect .../packages/<id>/<version>/...
  ver_dir="$(basename "$dir")"
  id_dir="$(basename "$(dirname "$dir")")"

  # Validate via nuspec if present
  nuspec_file="$(find "$dir" -maxdepth 2 -type f -name '*.nuspec' | head -n1 || true)"
  if [[ -f "$nuspec_file" ]]; then
    nuspec=$(cat "$nuspec_file")
    id=$(printf '%s' "$nuspec" | sed -n 's:.*<id>\([^<]*\)</id>.*:\1:p' | head -n1)
    ver=$(printf '%s' "$nuspec" | sed -n 's:.*<version>\([^<]*\)</version>.*:\1:p' | head -n1)
  else
    id="$id_dir"
    ver="$ver_dir"
  fi

  if [[ -z "${id:-}" || -z "${ver:-}" ]]; then
    printf "WARN: could not determine id/version for %s\n" "$dir" >&2
    continue
  fi

  # Compute SRI sha256 by prefetching the package from nuget v2 API
  url="https://www.nuget.org/api/v2/package/${id}/${ver}"
  if b32=$(nix-prefetch-url --type sha256 "$url" 2>/dev/null); then
    # Convert nix-base32 to SRI format with sha256- prefix
    sri=$(nix hash convert --hash-algo sha256 "$b32")
    entries+=("{\"pname\":\"$id\",\"version\":\"$ver\",\"hash\":\"$sri\"}")
    ((count++)) || true
    printf "\rProgress: %d/%d packages" "$count" "$total"
  else
    printf "\nWARN: failed to prefetch %s\n" "$url" >&2
  fi
done < <(find "$PACKAGES_DIR" -mindepth 2 -maxdepth 2 -type d -print0 | sort -z)

printf "\n"

if [[ ${#entries[@]} -eq 0 ]]; then
  printf "ERROR: No packages were processed\n" >&2
  exit 1
fi

# De-duplicate by (pname,version) and sort
json=$(printf '%s\n' "${entries[@]}" | jq -s 'unique_by(.pname + ":" + .version) | sort_by(.pname | ascii_downcase)')

# Automatically add linux-x64 RID siblings for any packages that have them
printf "Adding linux-x64 RID siblings...\n"
host_entries=()
mapfile -t host_packages < <(printf '%s\n' "$json" | jq -r '.[].pname' | grep -i '\.host$' || true)

for pkg in "${host_packages[@]}"; do
  pkg_lc=$(echo "$pkg" | tr '[:upper:]' '[:lower:]')
  mapfile -t vers < <(printf '%s\n' "$json" | jq -r --arg p "$pkg_lc" '[.[] | select((.pname|ascii_downcase)==$p) | .version] | unique[]?')

  for v in "${vers[@]}"; do
    # Check if linux-x64 sibling already exists
    sibling_name="${pkg%.host}.linux-x64"
    sibling_lc=$(echo "$sibling_name" | tr '[:upper:]' '[:lower:]')
    if printf '%s\n' "$json" | jq -e --arg s "$sibling_lc" --arg v "$v" 'any(.[]; ((.pname|ascii_downcase)==$s) and .version==$v)' >/dev/null; then
      continue
    fi

    url="https://www.nuget.org/api/v2/package/${sibling_name}/${v}"
    if b32=$(nix-prefetch-url --type sha256 "$url" 2>/dev/null); then
      sri=$(nix hash convert --hash-algo sha256 "$b32")
      host_entries+=("{\"pname\":\"$sibling_name\",\"version\":\"$v\",\"hash\":\"$sri\"}")
      printf "  Added sibling: %s %s\n" "$sibling_name" "$v"
    else
      printf "  WARN: No linux-x64 sibling for %s %s\n" "$pkg" "$v" >&2
    fi
  done
done

# Merge siblings into main json
if [[ ${#host_entries[@]} -gt 0 ]]; then
  json=$(printf '%s\n%s\n' "$json" "$(printf '%s\n' "${host_entries[@]}" | jq -s '.')" \
    | jq -s 'add | unique_by(.pname + ":" + .version) | sort_by(.pname | ascii_downcase)')
fi

# Filter out framework reference packages (provided by .NET SDK)
# These include Microsoft.*.App.Ref, Microsoft.*.App.Host, Microsoft.NETCore.App.*
json=$(printf '%s\n' "$json" | jq '[.[] | select(.pname | test("^(Microsoft|System)\\.(.*\\.App\\.Ref|.*\\.App\\.Host|NETCore\\.App)") | not)]')

# Write JSON
mkdir -p "$(dirname -- "$OUT")"
printf '%s\n' "$json" > "${OUT}"

count=$(jq length "$OUT")
printf 'Wrote %s with %d entries.\n' "$OUT" "$count"
