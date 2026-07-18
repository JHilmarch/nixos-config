#!/usr/bin/env bash
# T4/T8 seam: resolve which tracked security issues a passing update closes.
#
# Contract (stable — merge-blessed.sh calls this on the gate PASS path):
#   resolve-closes.sh --pr <N> --head-sha <SHA> --scan-csv <PATH>
#   stdout: zero or more `Closes: #<issue>` lines, one per resolved issue.
#   exit 0 always; nothing printed means nothing to close. All diagnostics go
#   to stderr — the caller captures stdout verbatim into the PR body.
#
# merge-blessed.sh appends this stdout to the PR body before the ff merge, so
# Forgejo auto-closes the referenced issues. A pure ff has no merge commit and
# amending the bump would change the gated SHA — the PR body is the churn-free
# close path.
#
# Resolution = CVE-set diff:
#   before   = open `security`-labelled issues, each tracking one CVE via the
#              `<!-- cve:CVE-YYYY-NNNNN -->` body marker written by
#              daily-scanners/reconcile-issues.sh (title regex as fallback).
#   after    = union of vuln_id across reports/gate/vulnxscan/scan-*.csv (every
#              CVE still present, regardless of severity or VEX whitelist).
#   resolved = before minus after -> print `Closes: #<n>`, sorted by number.
#
# The --scan-csv arg (failing-cves.csv) is only a fallback: it lists blocking
# rows and is empty on a pass, so diffing against it would wrongly close every
# open issue. The after-set comes from the raw per-closure scans instead.
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

# "after" set = every CVE still in the new closures (one scan-<i>.csv per closure).
shopt -s nullglob
scans=("$scan_dir"/scan-*.csv)
shopt -u nullglob
used_fallback=0
if [ "${#scans[@]}" -eq 0 ] && [ -n "$scan_csv" ] && [ -f "$scan_csv" ]; then
  # Fallback: failing-cves.csv understates "after" (blocking rows only).
  scans=("$scan_csv")
  used_fallback=1
fi
if [ "${#scans[@]}" -eq 0 ]; then
  warn "no vulnxscan CSVs under $scan_dir and no usable --scan-csv; after-set unknown — closing nothing."
  exit 0
fi

# Every CVE-* still present, regardless of severity or whitelist (FPAT parses quoted CSV).
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

# An empty after-set from the understated fallback is "unknown", not "CVE-free": never mass-close.
if [ "$used_fallback" -eq 1 ] && [ ! -s "$tmp/after" ]; then
  warn "only the understated --scan-csv fallback was available and it lists no CVEs; after-set unreliable — closing nothing."
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
