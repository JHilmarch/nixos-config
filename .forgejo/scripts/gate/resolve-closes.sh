#!/usr/bin/env bash
# T4/T8 seam: resolve which tracked security issues a passing update closes.
#
# Contract (stable — T4 calls this, T8 fills in the body):
#   resolve-closes.sh --pr <N> --head-sha <SHA> --scan-csv <PATH>
#   stdout: zero or more `Closes: #<issue>` lines, one per resolved issue.
#   exit 0 always on success; nothing printed means nothing to close.
#
# T4 (merge-blessed.sh) captures this stdout and appends it to the PR
# description before the fast-forward merge, so Forgejo auto-closes the
# referenced issues when the PR lands on the default branch. Under ff-only
# there is no merge commit to stamp, and amending the bump commit would change
# the gated SHA — the PR-body reference is the churn-free close path.
#
# THIS IS A STUB. It emits nothing so T4 ships without closing any issue.
# T8 replaces the body with the CVE-set diff:
#   * CVEs present on `blessed` before the bump  (open `security` issues, each
#     carrying a `<!-- cve:CVE-YYYY-NNNNN -->` marker — see
#     daily-scanners/reconcile-issues.sh)
#   * minus CVEs still present after the bump (this PR's vulnxscan CSV)
#   -> for each resolved CVE, look up its issue number by marker and print
#      `Closes: #<n>`.
#
# On any infra error T8 must still `exit 0` (best-effort): a passed security
# gate must never be blocked by issue bookkeeping.
set -euo pipefail

pr=""
head_sha=""
scan_csv=""
while [ $# -gt 0 ]; do
  case "$1" in
    --pr) pr="$2"; shift 2 ;;
    --head-sha) head_sha="$2"; shift 2 ;;
    --scan-csv) scan_csv="$2"; shift 2 ;;
    *) echo "resolve-closes: unknown arg: $1" >&2; exit 2 ;;
  esac
done

# Referenced so the stable arg contract is self-documenting and shellcheck-clean
# until T8 consumes them.
: "${pr}" "${head_sha}" "${scan_csv}"

# T8 fills in here. Stub closes nothing.
exit 0
