#!/usr/bin/env bash
# Gate step 3: vulnxscan the built closures and BLOCK on High/Critical CVEs.
#
# This is the "is this update safe" decision — the only blocking security step
# (the daily scanners are report-only). For each closure built in step 2 it runs
#   vulnxscan <closure> -o <csv> --whitelist <ACTIVE VEX>
# where the ACTIVE whitelist is computed first by vex-active.sh (T7): the raw
# vex/whitelist.csv pruned of expired/malformed entries, fail-closed, so stale
# suppressions lapse and their CVEs block again.
# vulnxscan annotates every finding with a `whitelist` column ("True"/"False")
# from the active VEX file rather than dropping it, and a `severity`
# column carrying the CVSS base score. The gate fails when ANY row has
#   severity >= CVSS_THRESHOLD (default 7.0)  AND  whitelist != "True"
# and the vuln_id is a real CVE-* (MAL-*/OSV-* without a CVSS score are out of
# scope for the CVSS gate — they surface in the report-only daily scanners).
#
# The offending rows are written to $GATE_FAILING_CVES (default
# reports/gate/failing-cves.csv) for block-pr.sh to comment on the PR, and the
# distinct failing CVE IDs to $GATE_FAILING_IDS for the T8 close-resolver seam.
#
# Env: GATE_CLOSURES_FILE, VEX_WHITELIST (default vex/whitelist.csv),
#      VEX_ACTIVE (default reports/gate/whitelist-active.csv),
#      CVSS_THRESHOLD (default 7.0), REPORTS_DIR, NVD_API_KEY (read by vulnxscan).
set -euo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
reports_dir="${REPORTS_DIR:-reports}"
closures_file="${GATE_CLOSURES_FILE:-$reports_dir/gate/closures.txt}"
vex="${VEX_WHITELIST:-${WORKSPACE:-.}/vex/whitelist.csv}"
vex_active="${VEX_ACTIVE:-$reports_dir/gate/whitelist-active.csv}"
threshold="${CVSS_THRESHOLD:-7.0}"
out_dir="$reports_dir/gate/vulnxscan"
failing_csv="${GATE_FAILING_CVES:-$reports_dir/gate/failing-cves.csv}"
failing_ids="${GATE_FAILING_IDS:-$reports_dir/gate/failing-ids.txt}"
mkdir -p "$out_dir" "$(dirname "$failing_csv")"

if [ ! -s "$closures_file" ]; then
  echo "::error title=gate-vulnxscan::no closures to scan ($closures_file empty) — build step must run first."
  exit 1
fi

bash "$here/vex-active.sh" "$vex" "$vex_active"
whitelist_args=(--whitelist "$vex_active")
echo "Applying active VEX whitelist: $vex_active (pruned from $vex)"

# Header for the merged failing-CVE report.
printf 'vuln_id,severity,package,version,url,closure\n' >"$failing_csv"
: >"$failing_ids"

i=0
while IFS= read -r closure; do
  [ -z "$closure" ] && continue
  i=$((i + 1))
  csv="$out_dir/scan-$i.csv"
  echo "::group::vulnxscan $closure"
  # vulnxscan exits non-zero when it finds vulns; that is data, not an error
  # here — the gate decision is made from the CSV, not the exit code.
  vulnxscan "$closure" -o "$csv" "${whitelist_args[@]}" || true
  echo "::endgroup::"

  [ -f "$csv" ] || continue

  # Select blocking rows: real CVE, CVSS >= threshold, not whitelisted.
  # gawk + FPAT parses quoted CSV fields. severity is a decimal CVSS score.
  gawk -v thr="$threshold" -v closure="$closure" '
    BEGIN { FPAT = "([^,]*)|(\"[^\"]*\")"; OFS="," }
    function unq(s){ gsub(/^"|"$/,"",s); return s }
    NR==1 { for (j=1;j<=NF;j++) col[unq($j)]=j; next }
    {
      id=unq($col["vuln_id"]); sev=unq($col["severity"])
      wl=(("whitelist" in col) ? unq($col["whitelist"]) : "")
      if (id !~ /^CVE-[0-9]{4}-[0-9]+$/) next
      if (wl == "True") next
      if (sev+0 < thr+0) next
      print id, sev, unq($col["package"]), unq($col["version"]), unq($col["url"]), closure
    }
  ' "$csv" >>"$failing_csv"
done <"$closures_file"

# Distinct failing CVE IDs (skip the CSV header).
tail -n +2 "$failing_csv" | cut -d, -f1 | sort -u >"$failing_ids"

count="$(wc -l <"$failing_ids" | tr -d ' ')"
if [ "$count" -gt 0 ]; then
  echo "::error title=gate-vulnxscan::$count High/Critical CVE(s) (CVSS >= $threshold, not whitelisted) block this update:"
  cat "$failing_ids"
  exit 1
fi

echo "No blocking CVEs (CVSS >= $threshold minus VEX). Security gate passed."
