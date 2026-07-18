#!/usr/bin/env bash
# Emit `changed=true|false` to $FORGEJO_OUTPUT depending on whether
# `nix flake update` left flake.lock modified in the worktree.
set -euo pipefail

if git diff --quiet -- flake.lock; then
  echo "changed=false" >>"$FORGEJO_OUTPUT"
  echo "flake.lock unchanged — nothing to PR"
else
  echo "changed=true" >>"$FORGEJO_OUTPUT"
fi
