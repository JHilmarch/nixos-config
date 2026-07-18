# VEX / vulnerability whitelist

`whitelist.csv` is the curated exception list the flake-update **gate** (`.forgejo/workflows/gate.yaml`, task T4)
consults before it blocks a merge on a High/Critical CVE. It is passed to `vulnxscan --whitelist`, so its format is the
[vulnxscan whitelist CSV](https://github.com/tiiuae/sbomnix/blob/main/doc/vulnxscan.md#whitelisting-vulnerabilities),
not a generic file.

The full curation policy and add-an-exception workflow are owned by task **T7**; this file ships as an empty, valid
whitelist so the gate's `--whitelist` step works from day one (an empty whitelist suppresses nothing — every CVSS ≥ 7.0
CVE still blocks).

## Format

A CSV with a header row. Columns:

| Column    | Required | Meaning                                                                             |
| --------- | -------- | ----------------------------------------------------------------------------------- |
| `vuln_id` | yes      | Regex matched against the finding's `vuln_id` (e.g. `CVE-2024-1234`, `CVE-2023.*`). |
| `comment` | yes      | Justification. **Every entry must state why the CVE is not applicable.**            |
| `package` | no       | If set, the entry only matches when the finding's `package` equals this exactly.    |

Rows higher in the file win when several match the same finding.

## How the gate uses it

`vulnxscan` does not drop whitelisted findings — it annotates each row with a `whitelist` column (`True`/`False`). The
gate (`.forgejo/scripts/gate/vulnxscan-gate.sh`) blocks a merge only on rows where `severity >= 7.0` **and**
`whitelist != "True"`. So adding a matching entry here turns a blocking CVE into a recorded, non-blocking exception
without silencing anything else.

## Adding an exception (summary — see T7 for the full policy)

1. The gate blocked a PR on `CVE-YYYY-NNNNN`.
1. Analyse it. If it genuinely does not affect this fleet, add one row: `CVE-YYYY-NNNNN,,<why it does not apply>` (add a
   `package` if the match should be package-scoped).
1. Keep it tight — one row per accepted CVE with a real reason. A blanket `.*` entry defeats the gate.

> Expiry (`until:`-style lapsing so stale suppressions re-surface) is a T7 deliverable. This stub does not implement it;
> do not treat entries here as permanent.
