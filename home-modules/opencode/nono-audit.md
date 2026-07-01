# OpenCode Nono Profile: Audit Log

Every `nono run` of the OpenCode agent leaves a tamper-evident audit trail. This document is the human-readable record
of where that trail lives, why it is append-only, how it rotates, and how to read it. The behaviour is provided by nono
itself (v0.61.1); this repo only configures rotation and a reading helper.

______________________________________________________________________

## Destination

nono writes an append-only, hash-chained audit trail to:

```
~/.nono/audit/<session-id>/
```

This is **host-side** state, outside the sandbox write scope. It is created and written by nono's out-of-sandbox
supervisor process, not by the sandboxed `opencode` child.

### Why not `~/.local/state/opencode/audit/`?

The path `~/.local/state/opencode/audit/` is a **dead end for an audit log**: the nono profile (`nono-profile.jsonc`)
grants the sandboxed process read-write access to `$XDG_STATE_HOME/opencode`, so the agent could read, append to, or
truncate any log stored there. An audit trail the audited process can rewrite is not an audit trail. nono's own
`~/.nono/audit/` is the correct destination precisely because the profile grants the sandbox **no access to `~/.nono`**
at all.

______________________________________________________________________

## Append-only semantics

The append-only guarantee is enforced by nono, not by filesystem permissions or a logrotate `create` mode:

- The `nono-profile.jsonc` filesystem allowlist does **not** list `~/.nono`. On Linux, granting a parent of `~/.nono`
  (e.g. `--allow ~`) is rejected at pre-flight, because Landlock cannot deny a child of an allowed parent. So the
  sandboxed opencode process has **no** read, write, unlink, or truncate access to the audit directory.
- Only nono's supervisor — which runs outside the Landlock sandbox — appends events. The audited agent cannot reach the
  trail to tamper with it.
- Each session's event log is **hash-chained**: `nono audit verify` recomputes the hashes from the event log and reports
  any break in the chain, so post-hoc edits by anything other than nono are detectable.

Verify the guarantee directly (the write from inside the sandbox must fail):

```fish
# From inside an opencode sandbox run, this is DENIED by the profile:
opencode run 'echo tamper >> ~/.nono/audit/anything'   # EACCES / permission denied

# From the host shell, confirm the chain is intact:
nono audit verify
```

______________________________________________________________________

## Rotation

nono stores one directory per session and never prunes automatically. Rotation is a weekly systemd **user** timer
(`opencode-audit-rotate`), declared in [`default.nix`](./default.nix) and gated on `programs.opencode.enable`:

| Knob      | Value                                          |
| --------- | ---------------------------------------------- |
| Schedule  | `OnCalendar = weekly`, `Persistent = true`     |
| Retention | prune sessions older than **180 days**         |
| Command   | `nono audit cleanup --older-than 180 --silent` |
| Safety    | `nono audit cleanup` skips active sessions     |

`--older-than 180` keeps roughly six months of forensic history. Sessions from the last 30 days are always well within
that window and are kept verbatim (nono has no separate compression step; each session is a small structured event log,
not a growing text file, so compression is unnecessary in v1). `Persistent = true` runs a missed clean-up on the next
boot if the machine was off at the scheduled time.

Force a rotation manually:

```fish
systemctl --user start opencode-audit-rotate.service
# Preview what a prune would remove without deleting:
nono audit cleanup --older-than 180 --dry-run
```

______________________________________________________________________

## Reading the log

Two fish abbreviations (declared in [`default.nix`](./default.nix)) read the trail from the **host** shell, where

## Acceptance-criteria mapping (T5 / #123)

| Criterion                                                                                                                | How it is met                                                                    |
| ------------------------------------------------------------------------------------------------------------------------ | -------------------------------------------------------------------------------- |
| Sample `opencode` run produces audit entries at the destination                                                          | nono auto-writes `~/.nono/audit/<session>/` for every `nono run` — always on     |
| Entries are append-only (in-sandbox `>>` fails)                                                                          | Profile grants the sandbox no access to `~/.nono`; only nono's supervisor writes |
| Rotation policy active                                                                                                   | `opencode-audit-rotate` weekly timer runs `nono audit cleanup --older-than 180`  |
| Reading alias / script exists                                                                                            | `oc-audit` / `oc-audit-verify` fish abbreviations                                |
| `~/.nono/audit` is readable. Inside opencode the same commands are denied by the profile — that is the boundary working  |                                                                                  |
| as designed. `nono` itself is on the host PATH via `home.packages` in [`default.nix`](./default.nix) (it otherwise lives |                                                                                  |
| only inside the opencode wrapper's `runtimeInputs`, i.e. inside the sandbox), so these host-side readers resolve.        |                                                                                  |

| Helper                 | Runs                                             | Purpose                                |
| ---------------------- | ------------------------------------------------ | -------------------------------------- |
| `oc-audit`             | `nono audit list --command opencode`             | List opencode sandbox sessions         |
| `oc-audit-verify [id]` | `nono audit verify <id>` (id defaults to latest) | Recompute the hash chain for a session |

`oc-audit` is a fish abbreviation; `oc-audit-verify` is a fish function, because `nono audit verify` requires a
`<SESSION_ID>` argument (there is no "verify all" form). Called with no argument it resolves the most recent opencode
session via `nono audit list --command opencode --recent 1 --json | jq -r '.[0].session_id'`; pass an explicit ID to
verify any other session.

Drill into a single session (the ID comes from `oc-audit`):

```fish
oc-audit                       # list recent opencode sessions
nono audit show <id> --json    # full audit detail for one session
nono logs --tail 50 <id>       # tail that session's raw event log
nono audit list --today        # only today's sessions
```

______________________________________________________________________

## Cross-Reference

- [`default.nix`](./default.nix) — the rotation timer and reading abbreviations (source of truth for the config).
- [`nono-profile.jsonc`](./nono-profile.jsonc) — the profile whose omission of `~/.nono` makes the trail append-only.
- [`nono-egress.md`](./nono-egress.md) — the network side of the same profile.
- [`README.md`](./README.md) — the overall OpenCode + nono setup.
