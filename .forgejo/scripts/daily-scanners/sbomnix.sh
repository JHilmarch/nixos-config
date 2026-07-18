#!/usr/bin/env bash
# sbomnix: CycloneDX + SPDX SBOM snapshot per target, archived as a job
# artifact. Report-only.
#
# Env: TARGETS (comma-separated flake attrs), REPORTS_DIR, GITHUB_WORKSPACE.
set +e

mkdir -p "$REPORTS_DIR/sbom"
flakeref="git+file://$GITHUB_WORKSPACE"
IFS=',' read -ra target_list <<<"$TARGETS"
rc_all=0

for t in "${target_list[@]}"; do
  safe=$(printf '%s' "$t" | tr -c 'A-Za-z0-9-' '_')
  echo "::group::sbomnix: $t"
  sbomnix "$flakeref#$t" \
    --cdx="$REPORTS_DIR/sbom/${safe}.cdx.json" \
    --spdx="$REPORTS_DIR/sbom/${safe}.spdx.json" \
    --csv="$REPORTS_DIR/sbom/${safe}.csv"
  rc=$?
  echo "::endgroup::"
  [ $rc -ne 0 ] && rc_all=$rc
done

if [ $rc_all -ne 0 ]; then
  echo "::warning title=sbomnix::one or more sbomnix invocations exited non-zero; report-only."
fi
exit 0
