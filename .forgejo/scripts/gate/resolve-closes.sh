#!/usr/bin/env bash
# T4/T8 seam: resolve which tracked security issues a passing update closes.
#
# Contract (stable — merge-blessed.sh calls this on the gate PASS path):
#   resolve-closes.sh --pr <N> --head-sha <SHA> --scan-csv <PATH>
#   stdout: zero or more `Closes: #<issue>` lines, one per resolved issue.
#   exit 0 always; nothing printed means nothing to close. All diagnostics go
#   to stderr — the caller captures stdout verbatim into the PR body.
#
# merge-blessed.sh appends this stdout to the PR description before the
# fast-forward merge, so Forgejo auto-closes the referenced issues when the PR
# lands on the default branch. Under ff-only there is no merge commit to stamp,
# and amending the bump commit would change the gated SHA — the PR-body
# reference is the churn-free close path.
#
# Resolution = CVE-set diff:
#   before   = open `security`-labelled issues, each tracking one CVE via the
#              `<!-- cve:CVE-YYYY-NNNNN -->` body marker written by
#              daily-scanners/reconcile-issues.sh (title regex as fallback).
#   after    = every CVE still detected in this PR's freshly built closures:
#              the union of vuln_id across reports/gate/vulnxscan/scan-*.csv,
#              regardless of severity or VEX whitelist status.
#   resolved = before minus after -> print `Closes: #<n>`, sorted by number.
#
# Why not the --scan-csv argument as the after-set: the caller passes
# failing-cves.csv, which holds only BLOCKING rows (CVE, CVSS >= threshold,
# not whitelisted) and is empty whenever the gate passes. Diffing against it
# would make every open CVE look resolved and wrongly close issues for CVEs
# that are still present but whitelisted or below the threshold. --scan-csv is
# only a defensive fallback when the raw scan dir is missing entirely.
#
# Token precedence: FORGEJO_ISSUE_TOKEN (issue-scoped, used by the daily
# scanners), else FORGEJO_PR_TOKEN (write:repository, present in the
# merge-blessed.sh env), else GITHUB_TOKEN. Issues are only READ here;
# merge-blessed.sh owns the PR-body patch and the merge.
#
# Env (optional): FORGEJO_API (default https://forge.fileshare.se/api/v1),
#   REPO (default jonatan/nixos-config), SECURITY_LABEL (default security,
#   matching reconcile-issues.sh), REPORTS_DIR (default reports).
#
# Best-effort: a passed security gate must never be blocked by issue
# bookkeeping. A missing token, unreachable API, or parse failure warns on
# stderr and exits 0 printing nothing — never close blindly.
set -uo pipefail

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

# Accepted for contract stability; resolution keys off scan artifacts + API.
: "${pr}" "${head_sha}"

api="${FORGEJO_API:-https://forge.fileshare.se/api/v1}"
repo="${REPO:-jonatan/nixos-config}"
label="${SECURITY_LABEL:-security}"
reports_dir="${REPORTS_DIR:-reports}"
scan_dir="$reports_dir/gate/vulnxscan"

warn() { echo "::warning title=resolve-closes::$*" >&2; }

token="${FORGEJO_ISSUE_TOKEN:-${FORGEJO_PR_TOKEN:-${GITHUB_TOKEN:-}}}"
if [ -z "$token" ]; then
  warn "no API token (FORGEJO_ISSUE_TOKEN/FORGEJO_PR_TOKEN/GITHUB_TOKEN); closing nothing."
  exit 0
fi

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

# --- "after" set: every CVE still detected in the new closures ----------------
shopt -s nullglob
scans=("$scan_dir"/scan-*.csv)
shopt -u nullglob
if [ "${#scans[@]}" -eq 0 ] && [ -n "$scan_csv" ] && [ -f "$scan_csv" ]; then
  # Defensive fallback only: failing-cves.csv understates "after" (blocking
  # rows only), so it is trusted solely when the raw scans are absent.
  scans=("$scan_csv")
fi
if [ "${#scans[@]}" -eq 0 ]; then
  warn "no vulnxscan CSVs under $scan_dir and no usable --scan-csv; after-set unknown — closing nothing."
  exit 0
fi

# A whitelisted or sub-threshold CVE is still PRESENT: keep its issue open.
# gawk + FPAT parses quoted CSV fields; FNR==1 re-maps each file's header.
if ! gawk '
  BEGIN { FPAT = "([^,]*)|(\"[^\"]*\")" }
  function unq(s){ gsub(/^"|"$/,"",s); return s }
  FNR==1 { delete col; for (j=1;j<=NF;j++) col[unq($j)]=j; next }
  ("vuln_id" in col) {
    id=unq($col["vuln_id"])
    if (id ~ /^CVE-[0-9]{4}-[0-9]+$/) print id
  }
' "${scans[@]}" | sort -u >"$tmp/after"; then
  warn "failed to parse vulnxscan CSVs; closing nothing."
  exit 0
fi

# --- "before" set: open tracked issues (cve TAB number) -----------------------
# Mirrors reconcile-issues.sh's paginated listing of open `security` issues.
page=1
: >"$tmp/open"
while :; do
  if ! json="$(curl -fsSL -H "Authorization: token $token" \
    "$api/repos/$repo/issues?state=open&type=issues&labels=$label&limit=50&page=$page")"; then
    warn "listing open '$label' issues failed (page $page); closing nothing."
    exit 0
  fi
  count="$(printf '%s' "$json" | jq -r 'if type=="array" then length else "bad" end' 2>/dev/null)" || count="bad"
  if [ -z "$count" ] || [ "$count" = "bad" ]; then
    warn "unexpected issue-list response (page $page); closing nothing."
    exit 0
  fi
  [ "$count" = "0" ] && break
  if ! printf '%s' "$json" | jq -r '
    .[]
    | . as $i
    | ((($i.body // "") | try (capture("<!-- cve:(?<c>CVE-[0-9]{4}-[0-9]+) -->").c) catch null)
       // (($i.title // "") | try (capture("(?<c>CVE-[0-9]{4}-[0-9]+)").c) catch null)) as $cve
    | select($cve != null)
    | "\($cve)\t\($i.number)"
  ' >>"$tmp/open" 2>/dev/null; then
    warn "extracting CVE markers failed (page $page); closing nothing."
    exit 0
  fi
  page=$((page + 1))
done

# --- resolved = before minus after -> Closes: trailers ------------------------
sort -u "$tmp/open" | while IFS=$'\t' read -r cve num; do
  grep -qFx "$cve" "$tmp/after" || printf '%s\n' "$num"
done | sort -nu | while IFS= read -r num; do
  printf 'Closes: #%s\n' "$num"
done

exit 0
