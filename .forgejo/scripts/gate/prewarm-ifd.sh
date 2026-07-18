#!/usr/bin/env bash
# Gate step 1.5: realise the llm-agents packages the gated host toplevels pull,
# so their bun2nix import-from-derivation resolves before build-hosts.sh evals.
#
# Why this exists: orion/p51 toplevels include llm-agents tooling (hunk,
# opencode, oh-my-opencode, ...) whose derivations use bun2nix. Evaluating
# those toplevels realises a fixed-output `cache-entry-creator` during eval
# (IFD). On a fresh llm-agents bump the runner store lacks that FOD and the LAN
# cache has never seen it, so the eval dies with "path ... is not valid" before
# any build starts. Building the packages here fetches the FOD into the store
# (it is a static input of e.g. hunk.drv), so the later toplevel eval finds it
# valid. It is content-addressed, so the path is identical regardless of the
# nixpkgs instantiation.
#
# The prewarm set is DERIVED from the flake (the llm-agents packages the config
# references), never hardcoded, so a new consumer is covered automatically. Each
# build takes a GC root under $REPORTS_DIR/gate/prewarm so an auto-GC between
# steps cannot evict the freshly realised paths.
#
# Best-effort: a prewarm build failure is only a warning — build-hosts.sh is the
# real gate and fails loudly if the toplevel eval still cannot proceed.
#
# Env: WORKSPACE (checked-out PR worktree), REPORTS_DIR (default reports).
set -euo pipefail

flakeref="${WORKSPACE:-.}"
reports_dir="${REPORTS_DIR:-reports}"
root_dir="$reports_dir/gate/prewarm"
mkdir -p "$root_dir"

system="$(nix eval --raw --impure --expr 'builtins.currentSystem')"

# The llm-agents package attrs the flake actually consumes, derived from the
# flake source so the set tracks the config. getFlake resolves the input with
# this flake's `follows` applied, so the realised paths match what the host
# toplevels evaluate.
mapfile -t pkgs < <(
  grep -rohE 'llm-agents\.packages\.\$\{[^}]*\}\.[a-zA-Z0-9_-]+' \
    "$flakeref/hosts" "$flakeref/home-modules" 2>/dev/null \
    | sed -E 's/.*\}\.//' \
    | sort -u
)

if [ "${#pkgs[@]}" -eq 0 ]; then
  echo "No llm-agents packages referenced; nothing to prewarm."
  exit 0
fi

echo "Prewarming ${#pkgs[@]} llm-agents package(s) for system $system:"
printf '  %s\n' "${pkgs[@]}"

for pkg in "${pkgs[@]}"; do
  echo "::group::prewarm $pkg"
  if nix build --impure \
    --expr "(builtins.getFlake \"$flakeref\").inputs.llm-agents.packages.${system}.${pkg}" \
    --out-link "$root_dir/$pkg"; then
    echo "prewarmed: $pkg"
  else
    echo "::warning title=gate-prewarm::prewarm build failed for $pkg; build-hosts.sh will surface any real eval failure."
  fi
  echo "::endgroup::"
done

echo "IFD prewarm complete."
