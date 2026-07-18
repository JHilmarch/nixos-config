#!/usr/bin/env bash
# nix_outdated: standing "you should bump" report. Flags runtime deps whose
# version is older than what nixpkgs unstable ships. Belongs in the daily
# report, NOT in any merge gate. Report-only.
#
# Env: TARGETS (comma-separated flake attrs), REPORTS_DIR, GITHUB_WORKSPACE.
set +e

mkdir -p "$REPORTS_DIR/nix_outdated"
flakeref="git+file://$GITHUB_WORKSPACE"
IFS=',' read -ra target_list <<<"$TARGETS"
rc_all=0

for t in "${target_list[@]}"; do
  safe=$(printf '%s' "$t" | tr -c 'A-Za-z0-9-' '_')
  echo "::group::nix_outdated: $t"
  nix_outdated "$flakeref#$t" --out="$REPORTS_DIR/nix_outdated/${safe}.csv"
  rc=$?
  echo "::endgroup::"
  [ $rc -ne 0 ] && rc_all=$rc
done

if [ $rc_all -ne 0 ]; then
  echo "::warning title=nix_outdated::one or more nix_outdated invocations exited non-zero; report-only."
fi
exit 0
