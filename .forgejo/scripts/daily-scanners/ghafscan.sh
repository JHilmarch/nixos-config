#!/usr/bin/env bash
# ghafscan: CVE drift over the live closures. Wraps vulnxscan (which reads
# NVD_API_KEY from env) and runs three lockfile states per target
# (current / lock_updated / nix_unstable). Report-only: a non-zero exit is
# surfaced as a warning and never fails the job.
#
# `git+file://$GITHUB_WORKSPACE` makes ghafscan's internal `nix flake clone`
# do a real git clone (preserving .git for its git.Repo() usage) rather than
# a bare path copy.
#
# Env: TARGETS (comma-separated flake attrs), REPORTS_DIR, GITHUB_WORKSPACE.
set +e

mkdir -p "$REPORTS_DIR/ghafscan"
flakeref="git+file://$GITHUB_WORKSPACE"
cmd=(ghafscan --verbose=1 --flakeref="$flakeref" --outdir="$REPORTS_DIR/ghafscan")

IFS=',' read -ra target_list <<<"$TARGETS"
for t in "${target_list[@]}"; do
  cmd+=(--target "$t")
done

echo "::group::ghafscan output"
"${cmd[@]}"
rc=$?
echo "::endgroup::"

if [ $rc -ne 0 ]; then
  echo "::warning title=ghafscan::ghafscan exited $rc; captured as a report-only result."
fi
echo "exit=$rc" >>"$GITHUB_OUTPUT"
exit 0
