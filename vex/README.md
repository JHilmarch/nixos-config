# VEX / vulnerability whitelist

`whitelist.csv` is the curated exception list the flake-update **gate** (`.forgejo/workflows/gate.yaml`) consults before
it blocks a merge on a High/Critical CVE. It is passed to `vulnxscan --whitelist`, so its on-disk format is the
[vulnxscan whitelist CSV](https://github.com/tiiuae/sbomnix/blob/main/doc/vulnxscan.md#whitelisting-vulnerabilities),
not a generic file. Expiry and curation policy are layered on top by the gate itself (see below), because vulnxscan has
no expiry concept.

## Format

A CSV with a header row. Columns (fixed — vulnxscan only understands these three):

| Column    | Required | Meaning                                                                                                                                                       |
| --------- | -------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `vuln_id` | yes      | One **literal** CVE id (e.g. `CVE-2024-1234`). vulnxscan treats this as a regex (fullmatch), but blanket/regex entries are rejected by the gate — see policy. |
| `package` | no       | If set, the entry only matches when the finding's `package` equals this exactly.                                                                              |
| `comment` | yes      | `until:YYYY-MM-DD` expiry token **plus** a human justification. Both mandatory.                                                                               |

Example entry:

```csv
vuln_id,package,comment
CVE-2024-99999,linux,until:2026-09-30 not reachable — module never loaded on our headless LXCs
```

Rows higher in the file win when several match the same finding. Quote the `comment` field if it contains commas.

## Expiry and enforcement

The expiry lives **inside the `comment` field** (the `until:YYYY-MM-DD` token) because vulnxscan would ignore any extra
column. It is enforced by a gate pre-step, `.forgejo/scripts/gate/vex-active.sh`, which runs before every scan and
writes the *active* whitelist (default `reports/gate/whitelist-active.csv`) that `vulnxscan --whitelist` actually
consumes. The raw `vex/whitelist.csv` is never handed to vulnxscan directly.

The pre-step keeps a row only if it passes **all** of these checks; everything else is dropped **fail-closed** (the row
provides no suppression, so its CVE re-surfaces and blocks the gate again), with a `::warning` in the run log naming the
dropped row and the reason:

- `vuln_id` is exactly one literal `CVE-YYYY-NNNNN`. Blanket entries (`.*`, `CVE-2024.*`, empty) are rejected — an entry
  that could whitelist more than one CVE defeats the gate.
- `comment` contains a well-formed `until:YYYY-MM-DD` token (the first one counts). Missing or malformed → dropped.
- The `until:` date is today (UTC) or later. The entry is honored through the stated date and lapses the day after.
- `comment` contains a real justification besides the `until:` token. A date alone is not a reason.
- The row parses as exactly three CSV fields. A malformed row would otherwise make vulnxscan reject the whole file.

## How the gate uses it

`vulnxscan` does not drop whitelisted findings — it annotates each finding with a `whitelist` column (`True`/`False`)
from the active whitelist. The gate (`.forgejo/scripts/gate/vulnxscan-gate.sh`) blocks a merge only on rows where
`severity >= 7.0` **and** `whitelist != "True"`. Adding a matching entry here therefore turns a blocking CVE into a
recorded, non-blocking exception without silencing anything else — and only until its `until:` date.

An empty whitelist (header only) is valid and suppresses nothing; every CVSS ≥ 7.0 CVE still blocks.

## Curation policy

- **One row per accepted CVE.** No blanket regexes, no shared rows.
- **Every row states why.** The justification must let a reviewer re-check the analysis later (why the CVE is a false
  positive or an accepted risk on this fleet).
- **Every row expires.** Pick the nearest `until:` date you can defend — typically ≤ 90 days. When it lapses, the CVE
  blocks again and the analysis must be redone before the entry is renewed with a fresh date.
- **Malformed means dropped.** A row that fails any check above is ignored (fail-closed), never silently honored.

## Adding an exception

1. The gate blocked a PR on `CVE-YYYY-NNNNN` (the PR comment lists the CVE, package, and CVSS score).
1. Analyse the finding. Only proceed if it genuinely does not affect this fleet (not reachable, not compiled in,
   mitigated by configuration) or the risk is explicitly accepted.
1. Add one row: `CVE-YYYY-NNNNN,<package or empty>,until:YYYY-MM-DD <why it does not apply>`. Scope it with `package`
   when the CVE is only a false positive for one package.
1. Land the row via a normal PR so the exception is reviewed; the next gate run annotates the CVE as whitelisted and
   stops blocking on it.
1. When the `until:` date passes, the entry lapses automatically: the gate warns that it dropped the expired row and the
   CVE blocks again if still present. Re-analyse and renew with a new date, or let the update path fix it.
