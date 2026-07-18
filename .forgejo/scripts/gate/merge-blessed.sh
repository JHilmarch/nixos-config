#!/usr/bin/env bash
# Gate step 5 (pass path): fast-forward-merge the PR to main, then advance the
# `blessed` ref to the exact gated commit.
#
# Mechanism (see the T4 design):
#   1. Append any `Closes: #<n>` lines from resolve-closes.sh (T8 seam) to the
#      PR description. Forgejo closes issues referenced in the PR body when the
#      PR merges into the default branch — no commit amend, no SHA churn.
#   2. Merge via the Forgejo API with Do:"fast-forward-only" and head_commit_id
#      pinned to the GATED SHA. ff-only lands the PR head verbatim on main (the
#      SHA we built + scanned == the SHA that merges); the pin aborts if the PR
#      head moved since the gate ran.
#   3. Push that same gated SHA to refs/heads/blessed with a plain (non-force)
#      git push. First run creates blessed; every later advance is a true ff.
#      A refused push means blessed moved out-of-band -> stop loudly, never
#      --force.
#
# Base-moved case: if main advanced since the PR branched, ff-only merge returns
# 405/409. We ask Forgejo to rebase the PR (update branch, style=rebase) and
# exit 0 without merging — the rewritten head fires a fresh gate run.
#
# Env (required):
#   FORGEJO_PR_TOKEN   token with write:repository (push + merge). Reused from T3.
#   PR_NUMBER          the flake-update PR index.
#   GATED_SHA          the PR head SHA the gate built + scanned (from the event).
# Env (optional):
#   FORGEJO_API (default https://forge.fileshare.se/api/v1)
#   REPO        (default jonatan/nixos-config)
#   BLESSED_REF (default blessed)
#   FORGEJO_HOST (default forge.fileshare.se)
#   REPORTS_DIR (default reports) — for the resolve-closes scan CSV path.
set -euo pipefail

api="${FORGEJO_API:-https://forge.fileshare.se/api/v1}"
repo="${REPO:-jonatan/nixos-config}"
blessed="${BLESSED_REF:-blessed}"
host="${FORGEJO_HOST:-forge.fileshare.se}"
reports_dir="${REPORTS_DIR:-reports}"
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

: "${FORGEJO_PR_TOKEN:?merge-blessed: FORGEJO_PR_TOKEN is required}"
: "${PR_NUMBER:?merge-blessed: PR_NUMBER is required}"
: "${GATED_SHA:?merge-blessed: GATED_SHA is required}"

auth=(-H "Authorization: token $FORGEJO_PR_TOKEN")
json=(-H 'Content-Type: application/json')

# --- 1. T8 seam: append Closes: trailers to the PR body -----------------------
closes="$(bash "$here/resolve-closes.sh" \
  --pr "$PR_NUMBER" \
  --head-sha "$GATED_SHA" \
  --scan-csv "$reports_dir/gate/failing-cves.csv" || true)"

if [ -n "$closes" ]; then
  echo "Resolved security issues to close on merge:"
  echo "$closes"
  current_body="$(curl -fsSL "${auth[@]}" "$api/repos/$repo/issues/$PR_NUMBER" | jq -r '.body // ""')"
  marker='<!-- gate:closes -->'
  # Replace any prior gate:closes block, then append a fresh one.
  base_body="${current_body%%"$marker"*}"
  new_body="$(printf '%s%s\n%s\n' "$base_body" "$marker" "$closes")"
  curl -fsSL -X PATCH "${auth[@]}" "${json[@]}" \
    -d "$(jq -n --arg b "$new_body" '{body:$b}')" \
    "$api/repos/$repo/issues/$PR_NUMBER" >/dev/null
  echo "Patched PR #$PR_NUMBER body with Closes: trailers."
fi

# --- 2. Fast-forward-only merge, pinned to the gated SHA -----------------------
merge_payload="$(jq -n --arg sha "$GATED_SHA" \
  '{Do:"fast-forward-only", head_commit_id:$sha, delete_branch_after_merge:true}')"

echo "::group::merge PR #$PR_NUMBER (fast-forward-only, pinned $GATED_SHA)"
http_code="$(curl -sS -o /tmp/merge-resp.json -w '%{http_code}' \
  -X POST "${auth[@]}" "${json[@]}" -d "$merge_payload" \
  "$api/repos/$repo/pulls/$PR_NUMBER/merge")"
echo "HTTP $http_code"
cat /tmp/merge-resp.json 2>/dev/null || true
echo
echo "::endgroup::"

case "$http_code" in
  200 | 201 | 204) echo "Merged PR #$PR_NUMBER to the default branch (ff-only)." ;;
  405 | 409)
    # Base moved -> can't ff. Ask Forgejo to rebase the PR; the resulting
    # synchronize event re-runs the gate on the new tree.
    echo "::warning title=gate-merge::ff-only merge rejected (HTTP $http_code); main moved. Rebasing PR #$PR_NUMBER; the gate will re-run."
    curl -fsSL -X POST "${auth[@]}" \
      "$api/repos/$repo/pulls/$PR_NUMBER/update?style=rebase" >/dev/null 2>&1 \
      || echo "::warning title=gate-merge::rebase request failed; leaving PR for the next scheduled run."
    exit 0
    ;;
  *)
    echo "::error title=gate-merge::unexpected merge response HTTP $http_code for PR #$PR_NUMBER."
    exit 1
    ;;
esac

# --- 3. Advance blessed to the gated SHA (plain ff push) ----------------------
# Push the GATED sha explicitly (not origin/main tip) so a merge that raced in
# right behind us can never drag blessed to an ungated commit.
push_url="https://oauth2:${FORGEJO_PR_TOKEN}@${host}/${repo}.git"
echo "::group::advance $blessed -> $GATED_SHA"
if git push "$push_url" "${GATED_SHA}:refs/heads/${blessed}"; then
  echo "Advanced $blessed to $GATED_SHA."
else
  echo "::error title=gate-blessed::non-fast-forward push to '$blessed' refused. Someone moved it out-of-band; not forcing. Merge to main succeeded — reconcile '$blessed' manually."
  echo "::endgroup::"
  exit 1
fi
echo "::endgroup::"
