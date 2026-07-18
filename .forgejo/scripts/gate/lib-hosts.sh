#!/usr/bin/env bash
# Derive the buildable host list from the flake, never hardcoded.
#
# Emits one flake attr path per line, e.g.
#   nixosConfigurations.nixos-edge.config.system.build.toplevel
# for every host in `self.nixosConfigurations` except the ones that have no
# `system.build.toplevel` a runner can build:
#   * iso       — image build, not a host toplevel
#   * wsl-cab   — WSL guest, not built in this fleet's CI
#   * nixos-cache — excluded from the fleet build set (mirrors prewarm.nix)
#
# Sourcing this file defines `gate_host_attrs`; running it directly prints the
# list. `nix eval` reads the flake in $WORKSPACE — the checked-out PR.
set -euo pipefail

# Hosts with no runner-buildable toplevel. Kept in sync with the fleet build
# set (see hosts/cache/prewarm.nix, which excludes the same non-toplevel hosts).
GATE_HOST_EXCLUDES="${GATE_HOST_EXCLUDES:-iso wsl-cab nixos-cache}"

gate_host_attrs() {
  local flakeref="${1:-${WORKSPACE:-.}}"
  local excludes_json
  # GATE_HOST_EXCLUDES is a space-separated list; intentional word-splitting.
  # shellcheck disable=SC2086
  excludes_json="$(printf '%s\n' $GATE_HOST_EXCLUDES | jq -R . | jq -s .)"

  nix eval --json "${flakeref}#nixosConfigurations" --apply builtins.attrNames 2>/dev/null \
    | jq -r --argjson excl "$excludes_json" '
        map(select(. as $h | ($excl | index($h)) | not))
        | .[]
        | "nixosConfigurations.\(.).config.system.build.toplevel"
      '
}

# Run directly -> print the attr list (one per line).
if [ "${BASH_SOURCE[0]}" = "${0}" ]; then
  gate_host_attrs "$@"
fi
