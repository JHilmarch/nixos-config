#!/usr/bin/env bash
# Gate step 1: `nix flake check` on the PR's checked-out tree.
#
# Eval + formatting + the flake's own checks. Any non-zero exit fails the gate
# job (this is a blocking gate, not the report-only daily scanners).
#
# Env: WORKSPACE — the checked-out PR worktree (the workflow sets it from the
# runner context; Forgejo and GitHub Actions share the same context shape).
set -euo pipefail

flakeref="${WORKSPACE:-.}"

echo "::group::nix flake check"
nix flake check "$flakeref" --no-build --show-trace
rc=$?
echo "::endgroup::"

exit $rc
