# runners — self-hosted CI runner host

A Proxmox LXC that will host the homelab's self-hosted CI runners, executing workflows for repositories on the
[`forge` host](../forge/README-forge.md).

- **Host:** `nixos-runners` (flake attribute) / `runners` (hostname), static IP `192.168.2.110`.

## How it works

The host imports [`templates/proxmox-lxc.nix`](../../templates/proxmox-lxc.nix), which provides the shared LXC base:
garbage collection, DNS via `systemd-resolved`, LAN nameserver/gateway defaults, SSH with an open firewall port, and
unprivileged+nesting container defaults. The host config declares only its delta: the hostname, the static IP
`192.168.2.110`, a capped Nix build environment, and SSH host key persistence.

`services.sshHostKeyPersistence` ([`modules/ssh-host-key-persistence/`](../../modules/ssh-host-key-persistence/)) is
enabled so the SSH host ed25519 key — and the age identity sops-nix derives from it — survives container
destroy/recreate via the `/persist` bind mount ([`../../tofu/runners.tf`](../../tofu/runners.tf)).

### Build environment

`nix.settings` caps the build environment so a heavy build cannot starve the fleet: `max-jobs = 6` bounds parallel
derivations to the container's core cap, `cores = 0` lets each build use all available cores, and `trusted-users`
includes `root` so `nixos-rebuild`'s build user accepts signed paths from the LAN cache non-interactively. The LAN cache
substituter (`https://cache.fileshare.se`) and its public key come from
[`../../modules/nix-cache-client.nix`](../../modules/nix-cache-client.nix) via the template — the host does not
redeclare them.

### Provisioning

The container (CT `110`) is created and sized by OpenTofu in [`../../tofu/runners.tf`](../../tofu/runners.tf): 6 cores,
12 GB memory, 4 GB swap, NVMe `local-lvm` rootfs, and a single `/persist` bind mount for the SSH host key. See
[`../../tofu/README.md`](../../tofu/README.md) for the full provisioning, bootstrap, and reboot-relock flow.

## Bootstrap

`tofu apply -target module.runners` creates the container **running** on DHCP from the base template. Converge it onto
this flake host config once, over `--target-host` (no push needed), then reboot onto the static IP. Run from the repo
root on p51:

```fish
# 1. Find the DHCP lease the template booted with.
ssh -o IdentitiesOnly=yes -i ~/.ssh/id_ed25519_tofu root@<proxmox-host> \
  'pct exec 110 -- /run/current-system/sw/bin/ip -4 -br addr show eth0'

# 2. Build + push the closure + activate (SSH drops mid-activation — expected, not a hang).
set lease <dhcp-addr-from-step-1>
sudo env NIX_SSHOPTS="-i /home/<user>/.ssh/id_ed25519_tofu -o IdentitiesOnly=yes" \
  nixos-rebuild switch --flake .#nixos-runners --target-host root@$lease

# 3. Reboot to settle onto the static IP 192.168.2.110.
ssh -o IdentitiesOnly=yes -i ~/.ssh/id_ed25519_tofu root@<proxmox-host> 'pct reboot 110'
```

Point `NIX_SSHOPTS` at the **absolute** key path — `sudo` runs as root, so a `~` there resolves to `/root`, not your
home. Later rebuilds target the static IP `192.168.2.110` directly and do not drop (networking no longer flips).

Verify:

```fish
ssh -o IdentitiesOnly=yes -i ~/.ssh/id_ed25519_tofu root@192.168.2.110 'hostname'                          # → runners
ssh -o IdentitiesOnly=yes -i ~/.ssh/id_ed25519_tofu root@<proxmox-host> 'pct config 110 | grep -E "cores|memory|swap"'  # cores=6 memory=12288 swap=4096
```

## Scheduled workflows

The runner executes workflows from `.forgejo/workflows/` in any repo that has Actions enabled. The host's own
[`configuration.nix`](./configuration.nix) and [`forgejo-runner.nix`](./forgejo-runner.nix) wire the secrets those
workflows need directly into the runner daemon's environment via SOPS-rendered `EnvironmentFile`s, so workflow steps
read them as plain env vars — no `${{ secrets.* }}` UI configuration required.

### `flake-update` — weekly `nix flake update` PR

[`.forgejo/workflows/flake-update.yaml`](../../.forgejo/workflows/flake-update.yaml) bumps `flake.lock` and opens a PR
against `jonatan/nixos-config` when any input rev moved.

- **Schedule:** Mondays 04:00 UTC (`cron: '0 4 * * 1'`). Manual runs via the Forgejo UI `workflow_dispatch` picker.
- **Runner label:** `nixos-x86_64` — matches the host-native runner (the `:host` runtime suffix on the label in
  `forgejo-runner.nix` is the execution scheme, not part of the match key).
- **Required secret:** `FORGEJO_PR_TOKEN` — a bot/deploy token with `write:repository` scope on `jonatan/nixos-config`.
  Declared as `sops.secrets."forgejo-pr-token"` in [`configuration.nix`](./configuration.nix) and surfaced to the
  workflow through the daemon `EnvironmentFile` in [`forgejo-runner.nix`](./forgejo-runner.nix) (same pattern as
  `nvd-api-key`). Operator stores the value as `FORGEJO_PR_TOKEN=<token>` in `secrets/runners/secrets.yml`.
- **No-op on clean lock:** if `nix flake update` produces no `flake.lock` diff, the workflow exits 0 without opening a
  PR. It never opens empty PRs.
- **PR body:** one line per changed top-level input (`name: oldrev -> newrev`) plus a reserved "Resolves security
  issues" section left empty for the closing logic (separate task) to populate.
- **Consumed by the gate:** each such PR is validated by [`gate.yaml`](#the-gate-forgejoworkflowsgateyaml) below, which
  fast-forward-merges it to `main` and advances `blessed` on a full pass, or leaves it open with the blocking findings
  on a failure.

## Files

| File                 | Purpose                                                                  |
| -------------------- | ------------------------------------------------------------------------ |
| `configuration.nix`  | Host config: networking, capped Nix build env, SSH host key persistence. |
| `home.nix`           | Minimal Home Manager config (fish, lsd, fzf, zoxide, broot, starship).   |
| `forgejo-runner.nix` | Runner registration, labels, host packages, daemon `EnvironmentFile`s.   |

The workflows keep only step wiring in YAML; each non-trivial step calls a script under `.forgejo/scripts/<workflow>/`
so the shell stays readable and independently checkable. These are bash (not fish): the Forgejo Actions steps run them
under `shell: bash`, and the runner ships bash + gawk + jq — same class as `scripts/*.sh`.

## Daily scanners (`.forgejo/workflows/daily-scanners.yaml`)

A **report-only** Forgejo Actions workflow that runs once a day (\`schedule: 0 5

- - \*\` UTC) and on manual dispatch. It surfaces "when to update" signals against the scanned closures and never blocks
    a merge.

### What it does

1. **Resolves the scanned ref.** Defaults to `blessed` (the future branch holding the blessed closures); if `blessed`
   does not exist yet, it falls back to `main`. The flip to `blessed` is automatic once the branch appears.
1. **`ghafscan`** — CVE drift over the live closures. Wraps `vulnxscan` (which reads `NVD_API_KEY` from the environment,
   injected below) and runs three lockfile states per target (`current` / `lock_updated` / `nix_unstable`).
1. **`nix_outdated`** — standing "runtime deps with a newer nixpkgs version" report. Belongs here in the report path,
   NOT in any gate.
1. **`sbomnix`** — CycloneDX + SPDX SBOM snapshot per run, archived under `reports/`.
1. **Reconciles `security`-labelled issues** via the Forgejo API. New CVE opens an issue; a CVE no longer detected
   closes its issue with a note. The CVE ID is embedded in both the title and a `<!-- cve:CVE-... -->` marker in the
   body so downstream automation can map `Closes: <CVE>` onto the right issue.
1. **Uploads `reports/`** as a job artifact (30-day retention).

Every scanner step captures non-zero exits as report-only warnings (`|| true` with explicit `::warning::` notices); a
finding never fails the job.

### Configuration

| Workflow input | Default                                                                                        | Meaning                                    |
| -------------- | ---------------------------------------------------------------------------------------------- | ------------------------------------------ |
| `scanned_ref`  | `blessed` (falls back to `main`)                                                               | Branch holding the closures to scan        |
| `targets`      | `nixosConfigurations.nixos-edge.config.system.build.toplevel,nixosConfigurations.nixos-forge…` | Comma-separated flake output attrs to scan |

The default `targets` is the two internet-facing LXC hosts. Expand to the full fleet (e.g. add `…nixos-cache…`,
`…nixos-runners…`) via the dispatch input.

### Required secret

`FORGEJO_ISSUE_TOKEN` — a Forgejo API token with `issue:write`, `label:write`, and `read:repository` scopes. It is
declared as the SOPS secret `forgejo-issue-token` in [`configuration.nix`](./configuration.nix) and surfaced into every
host-executed job shell via the runner daemon's `EnvironmentFile` in [`forgejo-runner.nix`](./forgejo-runner.nix),
mirroring the `nvd-api-key` pattern. The operator must store the value as `FORGEJO_ISSUE_TOKEN=<token>` in the SOPS file
(the encrypted value is **not** managed by this flake). If the secret is absent the workflow falls back to the automatic
`GITHUB_TOKEN`, which may lack the scopes needed to create issues.

The `security` label is created idempotently by the workflow on first run if it does not already exist (color
`#d73a4a`); pre-creating it manually is also fine.

### Artifact location

`reports/{ghafscan,nix_outdated,sbom}/` — packaged as the `daily-scanners-reports` job artifact, downloadable from the
workflow run page.

## The gate (`.forgejo/workflows/gate.yaml`)

The **blocking** counterpart to the daily scanners. It validates the flake-update PRs the `flake-update` workflow opens
and, on a full pass, fast-forwards them onto `main` and advances the `blessed` ref that hosts track. This is the "is
this update safe" decision.

- **Trigger:** `pull_request` (opened / synchronize / reopened) against `main`, gated to head branches matching
  `flake-update/*` — automated bumps only, not human PRs.
- **Runner label:** `nixos-x86_64`, same host-native runner as the other workflows.

### Pipeline

Fail-fast; the first red step blocks the merge and comments the reason on the PR.

1. **`nix flake check`** — eval + formatting + the flake's own checks.
1. **Build every host `system.build.toplevel`.** The host list is derived from `self.nixosConfigurations` (minus `iso`,
   `wsl-cab`, `nixos-cache`), never hardcoded, so a newly added host is gated automatically. A single build failure
   fails the gate. The LAN binary cache resolves most paths.
1. **`vulnxscan`** each built closure. Blocks on any `CVE-*` with `severity` (CVSS base score) `>= 7.0` that is not
   whitelisted by [`vex/whitelist.csv`](../../vex/whitelist.csv). Whitelisted and sub-threshold findings, and non-CVE
   (`MAL-*` / `OSV-*`) findings, do not block.
1. **Tests** — `nix flake check --keep-going` as the repo test gate.
1. **Pass** → fast-forward-only merge to `main`, then advance `blessed` to the exact gated commit. **Fail** → the PR is
   left open with the blocking findings commented on it.

### How the merge + `blessed` advance works

- The PR is merged with the Forgejo API `Do: "fast-forward-only"`, pinned to the gated head SHA (`head_commit_id`). The
  commit that was built and scanned is exactly the commit that lands on `main` — no rebase/squash SHA rewrite.
- `blessed` is then advanced with a plain (non-force) `git push` of that same gated SHA to `refs/heads/blessed`. The
  first passing run **creates** `blessed`; every later advance is a true fast-forward. A refused (non-ff) push means
  `blessed` was moved out of band — the gate stops loudly and never forces.
- If `main` moved since the PR branched, the ff-only merge is rejected; the gate asks Forgejo to rebase the PR, and the
  resulting `synchronize` event re-runs the whole gate on the new tree.

### `blessed` and the default branch

`main` stays the default branch (so Forgejo's close-on-merge fires). `blessed` is a strict trailing pointer inside
`main`'s history that only ever advances to gated commits. Hosts track `blessed`, not `main` — the pull-based update
flow is in [`tofu/README.md` "Ongoing host updates"](../../tofu/README.md#ongoing-host-updates-track-blessed), and
rolling `blessed` back after a bad update is in
[`README-forge.md` "Rolling back `blessed`"](../forge/README-forge.md#rolling-back-blessed). A non-gated commit landing
on `main` intentionally leaves `blessed` behind.

### VEX whitelist

[`vex/whitelist.csv`](../../vex/whitelist.csv) is the curated exception list (vulnxscan whitelist CSV format; `vuln_id`
regex + `comment`, optional `package`). It ships empty — nothing is suppressed until an entry is added. See
[`vex/README.md`](../../vex/README.md) for the format and the add-an-exception workflow.

### Closing security issues on merge

When a passing update resolves a tracked CVE, the merge closes its `security` issue via a `Closes: #<n>` line appended
to the PR description before merge (Forgejo closes body-referenced issues on merge to the default branch — no commit
amend, so the gated SHA is untouched). The CVE-set diff lives in
[`resolve-closes.sh`](../../.forgejo/scripts/gate/resolve-closes.sh): open `security` issues (the CVEs tracked against
`blessed`) minus every CVE still detected in the PR's fresh per-closure `vulnxscan` CSVs — severity and VEX whitelist
ignored, so a suppressed-but-present CVE keeps its issue open. Best-effort: on any API or artifact error it closes
nothing.

### Required secret

`FORGEJO_PR_TOKEN` — reuses the same `write:repository` token as the `flake-update` workflow (it merges the PR and
pushes `blessed`). `NVD_API_KEY`, already injected into the runner daemon, is read by `vulnxscan`. No new secret is
introduced. Because both the merge and the `blessed` push go through this token, its user must retain push access if
`main` or `blessed` is later branch-protected.

### Artifact location

`reports/gate/` — the derived closures list, per-closure `vulnxscan` CSVs, and the failing-CVE report, packaged as the
`gate-reports` job artifact.
