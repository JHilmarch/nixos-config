#!/usr/bin/env bash
# Reconcile `security`-labelled Forgejo issues against the current scan:
#   * new CVE    -> open issue (title + body carry the CVE marker)
#   * gone CVE   -> close its issue with a "no longer detected" note
#   * recurring  -> a fresh issue opens; the closed one is left as-is
#                   (the open-set lookup never matches it). Intentional for
#                   a report-only tracker.
#
# No per-run heartbeat comment (avoids daily spam); the issue's open state
# IS the heartbeat. Only CVE-* IDs are tracked (MAL-* and other vulnxscan
# findings are out of scope for the Closes:<CVE> contract).
#
# Env: FORGEJO_ISSUE_TOKEN (preferred) or GITHUB_TOKEN (fallback),
#      FORGEJO_API, REPO, SECURITY_LABEL, REPORTS_DIR, RESOLVED_REF,
#      GITHUB_SERVER_URL, GITHUB_RUN_ID.
set +e

if [ -n "$FORGEJO_ISSUE_TOKEN" ]; then
  TOKEN="$FORGEJO_ISSUE_TOKEN"
else
  echo "::warning title=reconcile::FORGEJO_ISSUE_TOKEN unset; falling back to the automatic GITHUB_TOKEN. Scope may be insufficient to create issues."
  TOKEN="$GITHUB_TOKEN"
fi
auth=(-H "Authorization: token $TOKEN" -H 'Content-Type: application/json')

ensure_label() {
  curl -fsSL -H "Authorization: token $TOKEN" \
    "$FORGEJO_API/repos/$REPO/labels/$SECURITY_LABEL" >/dev/null 2>&1 && return 0
  curl -fsSL -X POST "${auth[@]}" \
    -d '{"name":"security","color":"#d73a4a","description":"Open CVE surfaced by daily-scanners"}' \
    "$FORGEJO_API/repos/$REPO/labels" >/dev/null 2>&1
}
ensure_label

scan_date=$(date -u +%Y-%m-%d)
resolved_ref="$RESOLVED_REF"
run_url="${GITHUB_SERVER_URL:-https://forge.fileshare.se}/${REPO}/actions/runs/${GITHUB_RUN_ID:-0}"
data_csv="$REPORTS_DIR/ghafscan/data.csv"

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

# Current, non-whitelisted CVE-* IDs from ghafscan data.csv.
# gawk + FPAT splits quoted CSV fields correctly.
: >"$tmp/cves"
if [ -f "$data_csv" ]; then
  gawk '
    BEGIN { FPAT = "([^,]*)|(\"[^\"]*\")" }
    NR==1 { for (i=1;i<=NF;i++) col[$i]=i; next }
    ($col["pintype"]=="current") && \
    ($col["whitelist"]=="" || $col["whitelist"]=="False") {
      id=$col["vuln_id"]
      if (id ~ /^CVE-[0-9]{4}-[0-9]+$/) print id
    }
  ' "$data_csv" | sort -u >"$tmp/cves"
fi

# CVE -> issue-number for currently-open security issues.
page=1
: >"$tmp/open"
while :; do
  json=$(curl -fsSL -H "Authorization: token $TOKEN" \
    "$FORGEJO_API/repos/$REPO/issues?state=open&type=issues&labels=$SECURITY_LABEL&limit=50&page=$page" 2>/dev/null)
  count=$(printf '%s' "$json" | jq 'length' 2>/dev/null)
  [ "$count" = "0" ] && break
  [ -z "$count" ] && break
  printf '%s' "$json" \
    | jq -r '.[] | "\(.number)\t\(.title)"' \
    | while IFS=$'\t' read -r num title; do
        cve=$(printf '%s' "$title" | grep -oE 'CVE-[0-9]{4}-[0-9]+' | head -n1)
        [ -n "$cve" ] && printf '%s\t%s\n' "$cve" "$num" >>"$tmp/open"
      done
  page=$((page + 1))
done

# Open issues for newly-seen CVEs (de-duped against the open set).
while read -r cve; do
  [ -z "$cve" ] && continue
  if grep -qP "^$cve\t" "$tmp/open"; then
    printf '%s already tracked; skipping.\n' "$cve"
    continue
  fi
  payload=$(jq -n \
    --arg cve "$cve" \
    --arg date "$scan_date" \
    --arg ref "$resolved_ref" \
    --arg url "$run_url" \
    --arg label "$SECURITY_LABEL" \
    '{
      title: ("[security] " + $cve),
      body: ("<!-- cve:" + $cve + " -->\n\n" +
             "**CVE:** " + $cve + "\n\n" +
             "Surfaced by the daily-scanners workflow on " + $date + " " +
             "scanning ref `" + $ref + "`.\n\n" +
             "Workflow run: " + $url + "\n\n" +
             "This issue opened automatically and closes automatically " +
             "once the CVE is no longer detected in the scanned " +
             "closures. Do not edit the `<!-- cve:... -->` marker."),
      labels: [$label]
    }')
  created=$(curl -fsSL -X POST "${auth[@]}" -d "$payload" \
    "$FORGEJO_API/repos/$REPO/issues" 2>/dev/null)
  num=$(printf '%s' "$created" | jq -r '.number // "?"')
  echo "Opened $cve as #$num"
done <"$tmp/cves"

# Close issues whose CVE is no longer in the current scan.
while IFS=$'\t' read -r cve num; do
  [ -z "$cve" ] && continue
  if ! grep -qFx "$cve" "$tmp/cves"; then
    comment=$(jq -n --arg cve "$cve" --arg date "$scan_date" --arg ref "$resolved_ref" \
      '{body:("[daily-scanners] CVE " + $cve + " no longer detected in the " + $date + " scan of ref \"" + $ref + "\"; auto-closing. Reopens if it recurs.")}')
    curl -fsSL -X POST "${auth[@]}" -d "$comment" \
      "$FORGEJO_API/repos/$REPO/issues/$num/comments" >/dev/null 2>&1
    curl -fsSL -X PATCH "${auth[@]}" -d '{"state":"closed"}' \
      "$FORGEJO_API/repos/$REPO/issues/$num" >/dev/null 2>&1
    echo "Closed #$num (CVE $cve no longer detected)"
  fi
done <"$tmp/open"

exit 0
