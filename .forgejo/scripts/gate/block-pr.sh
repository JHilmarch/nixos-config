#!/usr/bin/env bash
# Gate fail path: leave the PR open and comment the blocking findings on it.
#
# Invoked when any gate step fails (flake check, a host build, the vulnxscan
# CVSS gate, or tests). If the vulnxscan step produced a failing-CVE report, the
# comment lists the offending CVEs; otherwise it names the failed stage. The PR
# is never merged and never closed — the operator fixes the pin, whitelists a
# false positive in vex/whitelist.csv (T7), or lets the next update supersede it.
#
# Env (required): FORGEJO_PR_TOKEN, PR_NUMBER.
# Env (optional): FORGEJO_API, REPO, REPORTS_DIR, FAILED_STAGE, SERVER_URL,
#                 RUN_ID (instance URL + run id from the runner context).
set -euo pipefail

api="${FORGEJO_API:-https://forge.fileshare.se/api/v1}"
repo="${REPO:-jonatan/nixos-config}"
reports_dir="${REPORTS_DIR:-reports}"
failing_csv="${GATE_FAILING_CVES:-$reports_dir/gate/failing-cves.csv}"
stage="${FAILED_STAGE:-unknown}"

: "${FORGEJO_PR_TOKEN:?block-pr: FORGEJO_PR_TOKEN is required}"
: "${PR_NUMBER:?block-pr: PR_NUMBER is required}"

auth=(-H "Authorization: token $FORGEJO_PR_TOKEN")
json=(-H 'Content-Type: application/json')
run_url="${SERVER_URL:-https://forge.fileshare.se}/${repo}/actions/runs/${RUN_ID:-0}"

# Build the CVE table from the report, if the vulnxscan step wrote one.
cve_section=""
if [ -s "$failing_csv" ] && [ "$(tail -n +2 "$failing_csv" | wc -l | tr -d ' ')" -gt 0 ]; then
  rows="$(tail -n +2 "$failing_csv" \
    | awk -F, '{printf "| %s | %s | %s | %s |\n", $1, $2, $3, $4}' \
    | sort -u)"
  cve_section="$(printf '\n\n**Blocking CVEs** (CVSS ≥ 7.0, not whitelisted):\n\n| CVE | CVSS | package | version |\n| --- | --- | --- | --- |\n%s\n\nWhitelist a genuine false positive in `vex/whitelist.csv` (see `vex/README.md`), or wait for an update that drops the CVE.' "$rows")"
fi

body="$(printf '### 🚫 flake-update gate blocked this PR\n\nStage: **%s**.%s\n\nWorkflow run: %s\n\n_This PR is left open. It will not auto-merge to `blessed` until the gate passes._' \
  "$stage" "$cve_section" "$run_url")"

curl -fsSL -X POST "${auth[@]}" "${json[@]}" \
  -d "$(jq -n --arg b "$body" '{body:$b}')" \
  "$api/repos/$repo/issues/$PR_NUMBER/comments" >/dev/null

echo "Commented gate-block on PR #$PR_NUMBER (stage: $stage)."
