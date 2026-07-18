#!/usr/bin/env bash
# Gate step 2: build every buildable host's system.build.toplevel.
#
# The host list is DERIVED from the flake (lib-hosts.sh), never hardcoded, so a
# newly added host is gated automatically. Any single build failure fails the
# gate — hosts are never silently skipped. The LAN binary cache (T2) resolves
# most paths, so this is fast on the runner.
#
# The built store paths are written one per line to $GATE_CLOSURES_FILE
# (default reports/gate/closures.txt) for the vulnxscan step to consume.
#
# Env: WORKSPACE (checked-out PR worktree), REPORTS_DIR (default: reports),
#      GATE_CLOSURES_FILE.
set -euo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/dev/null
source "$here/lib-hosts.sh"

flakeref="${WORKSPACE:-.}"
reports_dir="${REPORTS_DIR:-reports}"
closures_file="${GATE_CLOSURES_FILE:-$reports_dir/gate/closures.txt}"
mkdir -p "$(dirname "$closures_file")"
: >"$closures_file"

mapfile -t attrs < <(gate_host_attrs "$flakeref")
if [ "${#attrs[@]}" -eq 0 ]; then
  echo "::error title=gate-build::no buildable hosts derived from the flake — refusing to pass an empty gate."
  exit 1
fi

echo "Gating ${#attrs[@]} host toplevel(s):"
printf '  %s\n' "${attrs[@]}"

fail=0
for attr in "${attrs[@]}"; do
  echo "::group::nix build $attr"
  # --print-out-paths gives us the closure path to hand to vulnxscan.
  if out="$(nix build "${flakeref}#${attr}" --no-link --print-out-paths 2>&1 | tee /dev/stderr | tail -n1)" \
    && [ -n "$out" ] && [ -e "$out" ]; then
    printf '%s\n' "$out" >>"$closures_file"
    echo "built: $out"
  else
    echo "::error title=gate-build::build failed for $attr"
    fail=1
  fi
  echo "::endgroup::"
done

if [ "$fail" -ne 0 ]; then
  echo "::error title=gate-build::one or more host toplevels failed to build — gate blocked."
  exit 1
fi

echo "All host toplevels built. Closures written to $closures_file."
