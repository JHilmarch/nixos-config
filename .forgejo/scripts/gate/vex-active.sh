#!/usr/bin/env bash
# Gate pre-step: compute the ACTIVE (effective) VEX whitelist.
#
# vulnxscan's whitelist CSV has no expiry concept — it only understands the
# columns vuln_id,package,comment. Expiry and curation policy are enforced
# HERE instead: every entry's comment must carry an `until:YYYY-MM-DD` token
# plus a human justification. This script copies vex/whitelist.csv to an
# "active" whitelist containing only the rows that pass policy; the gate
# points `vulnxscan --whitelist` at the active file, so a dropped row's CVE
# re-surfaces and blocks again (fail-closed).
#
# Dropped, each with a ::warning naming the row: expired entries, entries
# missing the until: token or a justification, malformed rows, and any
# vuln_id that is not one literal CVE id (blanket regexes like `.*` are
# rejected). A missing/empty raw whitelist yields a valid header-only active
# whitelist, which suppresses nothing.
#
# Usage: vex-active.sh [<raw_csv> [<active_csv>]]
# Env: VEX_WHITELIST (default $WORKSPACE/vex/whitelist.csv),
#      VEX_ACTIVE (default $REPORTS_DIR/gate/whitelist-active.csv),
#      VEX_TODAY (YYYY-MM-DD, UTC; override for tests).
set -euo pipefail

raw="${1:-${VEX_WHITELIST:-${WORKSPACE:-.}/vex/whitelist.csv}}"
active="${2:-${VEX_ACTIVE:-${REPORTS_DIR:-reports}/gate/whitelist-active.csv}}"
today="${VEX_TODAY:-$(date -u +%F)}"
mkdir -p "$(dirname "$active")"

printf 'vuln_id,package,comment\n' >"$active"

if [ ! -f "$raw" ]; then
  echo "::warning title=vex-active::VEX whitelist $raw not found; using an empty active whitelist."
  exit 0
fi

# gawk + FPAT parses quoted CSV. Kept rows are re-emitted verbatim (quoting
# preserved) in canonical column order; the checks use the unquoted values.
# The first until: token in a comment is the one that counts.
gawk -v today="$today" -v active="$active" '
  BEGIN { FPAT = "([^,]*)|(\"[^\"]*\")"; OFS = "," }
  function unq(s) { gsub(/^"|"$/, "", s); return s }
  function drop(reason) {
    printf "::warning title=vex-active::dropping whitelist row %d (vuln_id=%s): %s\n", \
      NR, unq($col["vuln_id"]), reason
    dropped++
  }
  { sub(/\r$/, "") }
  NR == 1 {
    for (j = 1; j <= NF; j++) col[unq($j)] = j
    if (!("vuln_id" in col) || !("package" in col) || !("comment" in col)) {
      print "::warning title=vex-active::whitelist header must be vuln_id,package,comment; ignoring all entries"
      bad_header = 1
    }
    next
  }
  /^[[:space:]]*$/ { next }
  bad_header { next }
  {
    total++
    if (NF != 3) { drop("malformed row (expected 3 CSV fields, got " NF ")"); next }
    id = unq($col["vuln_id"])
    if (id !~ /^CVE-[0-9]{4}-[0-9]+$/) {
      drop("vuln_id must be one literal CVE id; blanket/regex entries are rejected")
      next
    }
    c = unq($col["comment"])
    if (c !~ /until:/) { drop("missing required until:YYYY-MM-DD expiry"); next }
    if (match(c, /until:[0-9]{4}-(0[1-9]|1[0-2])-(0[1-9]|[12][0-9]|3[01])/) == 0) {
      drop("malformed until: date (need until:YYYY-MM-DD)")
      next
    }
    d = substr(c, RSTART + 6, 10)
    if (d < today) { drop("expired " d "; its CVE blocks again if still present"); next }
    just = c
    gsub(/until:[0-9]{4}-[0-9]{2}-[0-9]{2}/, "", just)
    gsub(/[[:space:]]+/, "", just)
    if (just == "") { drop("no justification besides the until: token"); next }
    print $col["vuln_id"], $col["package"], $col["comment"] >>active
    kept++
  }
  END {
    printf "Active VEX whitelist: kept %d of %d entries (today=%s UTC, dropped %d) -> %s\n", \
      kept + 0, total + 0, today, dropped + 0, active
  }
' "$raw"
