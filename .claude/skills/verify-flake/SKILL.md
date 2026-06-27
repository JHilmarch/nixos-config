---
name: verify-flake
description: "Use after editing .nix files in this repo to verify changes fast without a full toplevel build. Staged recipe — targeted nix eval on the smallest affected attribute, then nix flake check, then nix build only as a final gate. Triggers: \"verify nix change\", \"check flake\", \"verify flake\", \"did this break anything\", and any time you finish editing .nix files."
---

# Verify Flake

## Overview

Full `nix build .#nixosConfigurations.<host>.toplevel` takes minutes because it forces the entire system closure. For an edit loop that's wasteful — most changes only touch one attribute. This skill gives the **staged fast-verification recipe**: prove the change type-checks in seconds via `nix eval`, run `nix flake check` for formatting/derivations, and reserve `nix build` for non-trivial or final-gate verification.

**Core principle:** Evaluate the **smallest attribute that exercises your change**. Deeper = faster.

**Announce at start:** "I'm using the verify-flake skill to check this Nix change."

## When to use

- After editing any `.nix` file in this repo (modules, home-modules, hosts, packages, flake.nix itself).
- Before committing Nix changes.
- When you say "verify this", "check the flake", "did I break anything".
- **Do NOT use** for non-Nix edits — `nix fmt` / treefmt handles formatting via the formatter, not this skill.

## The staged recipe

Work through the stages in order. Stop early if a stage fails — fix and re-run that stage before moving on.

### Stage 1 — Identify what changed

```bash
git diff --name-only                 # against staged + unstaged changes
git diff --name-only main...HEAD     # if working on a feature branch
```

Filter to `.nix` files. If `flake.nix` itself changed, treat that as affecting **every** attribute (be conservative — go to stage 5).

### Stage 2 — Map changed paths to flake attributes

Use this cheatsheet. For shared modules, find every consuming host with `rg`:

```bash
# Which hosts import a changed home-module?
rg -l 'home-modules/opencode' hosts/*/home.nix
# Which hosts import a changed system module?
rg -l 'modules/yubikey-usbip' hosts/*/configuration.nix
```

| Changed path | Affected flake attribute |
| --- | --- |
| `hosts/orion/**` | `.#nixosConfigurations.nixos-orion` |
| `hosts/p51/**` | `.#nixosConfigurations.nixos-p51` |
| `hosts/wsl-cab/**` | `.#nixosConfigurations.wsl-cab` |
| `hosts/iso/**` | `.#nixosConfigurations.iso` |
| `hosts/hl-jump/**` | `.#nixosConfigurations.hl-jump` |
| `modules/**` | every host whose `configuration.nix` imports it (grep to find which) |
| `home-modules/**` | every host whose `home.nix` imports it (grep to find which) |
| `packages/<name>/**` | `.#packages.${system}.<name>` |
| `templates/**` | every host that imports the template |
| `treefmt.nix` | `.#formatter.${system}` and `.#checks.${system}.formatting` |
| `flake.nix` | **everything** — skip to stage 5 |

For this flake, `system` is always `x86_64-linux`.

### Stage 3 — Targeted `nix eval` (seconds)

Evaluate the **deepest specific attribute** that exercises your change. Deeper = faster because Nix only forces what's referenced.

```bash
# Fastest: just the option/value you touched (sub-second)
nix eval \
  .#nixosConfigurations.nixos-p51.config.home-manager.users.jonatan.programs.opencode.package

# Still fast: a single package output path (~1s)
nix eval --raw .#packages.x86_64-linux.gh-personal.outPath

# Heavier but still much faster than a full build: the host's toplevel outPath (~5-30s)
nix eval --raw .#nixosConfigurations.nixos-p51.config.system.build.toplevel.outPath
```

**Rule of thumb:** if you changed one option in a module, eval that exact option path on a host that uses the module. If you changed a package, eval the package. Only fall back to the full toplevel outPath when your change is broad within a host.

**Multiple hosts affected?** Eval each one — they're independent and each takes seconds.

A successful `nix eval` proves your change type-checks and the attribute path is valid. It does **not** prove the derivation builds. For that, go to stage 5.

### Stage 4 — `nix flake check` (formatting + derivation validity)

```bash
nix flake check
```

This runs `.#checks.${system}.formatting` (treefmt: alejandra for Nix, mdformat for Markdown, fish_indent for Fish, biome for JS/TS/JSON/CSS/HTML) and verifies every derivation. It does **not** build them.

If this fails on formatting, run `nix fmt` and re-check. The repo's git hooks auto-format on Write/Edit, but `nix flake check` is the source of truth.

### Stage 5 — `nix build` (final gate, optional)

Only run a full build when:

- Your change is non-trivial (a new module, a packaging change, anything that could fail at build time).
- Stage 3 used the full toplevel outPath AND stage 4 passes AND you're about to commit/merge.
- `flake.nix` itself changed (stage 1 escalation).

```bash
# A single host's toplevel (1-5 min on a warm store, longer cold)
nix build --out-link /tmp/p51-toplevel \
  .#nixosConfigurations.nixos-p51.config.system.build.toplevel

# A single package
nix build --out-link /tmp/pkg .#packages.x86_64-linux.<name>
```

**Skip stage 5 entirely** for pure option-value changes, comment/doc edits, or moves that `nix eval` already proved valid. The agent's time (and the user's tokens) are worth more than belt-and-suspenders build certainty for trivial changes.

## Worked examples

### Example A — added an option to `home-modules/opencode/default.nix`

```bash
# 1. What changed?
git diff --name-only
# → home-modules/opencode/default.nix

# 2. Who uses it?
rg -l 'home-modules/opencode' hosts/*/home.nix
# → hosts/orion/home.nix
# → hosts/p51/home.nix

# 3. Eval the new option path on each consumer (sub-second each)
nix eval .#nixosConfigurations.nixos-p51.config.home-manager.users.jonatan.modules.opencode.persistentDirs
nix eval .#nixosConfigurations.nixos-orion.config.home-manager.users.jonatan.modules.opencode.persistentDirs

# 4. Flake check
nix flake check

# Stage 5 skipped — option-value change, eval + flake check is sufficient.
```

Total: ~5 seconds for full verification.

### Example B — added a new package under `packages/foo/`

```bash
# 1. Changed files
git diff --name-only
# → packages/foo/default.nix

# 2. Attribute: .#packages.x86_64-linux.foo (assumes packages/default.nix exposes it via callPackages)

# 3. Eval the package
nix eval --raw .#packages.x86_64-linux.foo.outPath

# 4. Flake check (will surface a missing attribute if the package isn't wired in)

# 5. Build the package (non-trivial — it's a new derivation)
nix build --out-link /tmp/foo .#packages.x86_64-linux.foo
```

Total: ~30 seconds if the build is cached, longer if not.

## Attribute path cheatsheet (this flake)

```
.#nixosConfigurations.{nixos-orion,nixos-p51,wsl-cab,iso,hl-jump}
.#nixosConfigurations.<host>.config.system.build.toplevel.outPath   # full system
.#nixosConfigurations.<host>.config.home-manager.users.jonatan.<...> # HM user config
.#packages.x86_64-linux.<name>                                       # custom packages (pkgs.local.*)
.#formatter.x86_64-linux                                             # treefmt wrapper
.#checks.x86_64-linux.formatting                                     # treefmt check
.#devShells.x86_64-linux.default                                     # nix develop
```

`system` is always `x86_64-linux` for this flake.

## Common mistakes

### Evaluating the wrong attribute path

- **Problem:** `nix eval` succeeds but you verified the wrong thing — false confidence.
- **Fix:** Cross-check the path against `flake.nix` and the module's option namespace. HM options live under `config.home-manager.users.<user>.<...>`, not `config.programs.<...>`, when using the NixOS module integration pattern.

### Jumping straight to `nix build`

- **Problem:** Wastes minutes on a change that would have failed `nix eval` in seconds. Also burns agent tokens.
- **Fix:** Always start at stage 3. `nix build` is stage 5, not stage 1.

### Running `nix flake check` only at the end

- **Problem:** A formatting failure on line 1 of a 5-file diff wastes the time you spent on stages 3-4.
- **Fix:** Stage 4 (`nix flake check`) is cheap — run it right after stage 3 succeeds.

### Treating `nix eval` success as "it builds"

- **Problem:** `nix eval` forces the attribute's evaluation, not the build. A derivation can eval fine and still fail to build (missing source, broken builder, etc.).
- **Fix:** For non-trivial changes, run stage 5 before declaring done. For trivial option-value changes, stage 3 success is sufficient evidence.

### Forgetting that `modules/` and `home-modules/` are shared

- **Problem:** You change `home-modules/git/default.nix` and only verify on orion — but the module is imported by 4 hosts. The other 3 might break.
- **Fix:** Always `rg -l '<path>' hosts/*/home.nix hosts/*/configuration.nix` to find every consumer, and eval each one. Stages 3-4 are cheap enough to do per-host.

## Red flags

**Never:**

- Run `nix build .#nixosConfigurations.<host>.toplevel` as a first-line verification.
- Skip `rg -l` when changing anything under `modules/` or `home-modules/`.
- Trust a `nix eval` of the wrong attribute path — read the path aloud and confirm it corresponds to your change.
- Use `nix-build` (legacy) — this flake uses the `nix` v2 command set exclusively.

**Always:**

- Announce the skill before running stages.
- Eval the **deepest specific attribute** first.
- Run `nix flake check` even when you're "sure" formatting is fine.
- Report what you evaluated and how long it took in your final answer — gives the user confidence the verification was real, not gestured.
