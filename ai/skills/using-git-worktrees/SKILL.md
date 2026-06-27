---
name: using-git-worktrees
description: Use when starting feature work that needs isolation from current workspace or before executing implementation plans - creates isolated git worktrees with smart directory selection and safety verification.
---

# Using Git Worktrees

## Overview

Git worktrees create isolated workspaces sharing the same repository, allowing work on multiple branches simultaneously
without switching.

**Core principle:** Systematic directory selection + safety verification = reliable isolation.

**Announce at start:** "I'm using the using-git-worktrees skill to set up an isolated workspace."

## Directory Selection Process

Follow this priority order:

### 1. Check Existing Directories

```bash
# Check in priority order
ls -d ~/.worktrees 2>/dev/null # Preferred
ls -d ./worktrees 2>/dev/null # Alternative
```

**If found:** Use that directory. If both exist, `~/.worktrees` wins.

### 2. Check AGENTS.md

```bash
grep -i "worktree.*director" AGENTS.md 2>/dev/null
```

**If preference specified:** Use it without asking.

### 3. Ask User

If no directory exists and no AGENTS.md preference:

```
No worktree directory found. Where should I create worktrees?
1. ~/.worktrees/  (global location)
2. .worktrees/    (project-local, hidden)
Which would you prefer?
```

## Safety Verification

### For Project-Local Directories (./worktrees)

**MUST verify directory is ignored before creating worktree:**

```bash
# Check if directory is ignored (respects local, global, and system gitignore)
git check-ignore -q .worktrees 2>/dev/null || git check-ignore -q worktrees 2>/dev/null
```

**If NOT ignored:** Immediately fix by:

1. Add appropriate line to .gitignore
1. Commit the change
1. Proceed with worktree creation

**Why critical:** Prevents accidentally committing worktree contents to repository.

### For Global Directory (~/.worktrees)

No .gitignore verification needed - outside project entirely.

## Creation Steps

### 1. Detect Project Name

```bash
project=$(basename "$(git rev-parse --show-toplevel)")
```

### 2. Create Worktree

```bash
# Determine full path
case $LOCATION in
  .worktrees)
    path="$LOCATION/$BRANCH_NAME"
    ;;
  ~/.worktrees/*)
    path="~/.worktrees/$project/$BRANCH_NAME"
    ;;
esac

# Create worktree with new branch
git worktree add "$path" -b "$BRANCH_NAME"
cd "$path"
```

### 3. Run Project Setup

Auto-detect (check README.md / AGENTS.md) and run appropriate setup. This could be installing node dependencies, using
dotnet build, etc.

### 4. Verify Clean Baseline

Run tests to ensure worktree starts clean:

```bash
# Examples - use project-appropriate command
npm test
pnpm test
cargo test
dotnet test
```

**If tests fail:** Report failures, ask whether to proceed or investigate. **If tests pass:** Report ready.

### 5. Report Location

```
Worktree ready at <path>
Tests passing (<N> tests, 0 failures)
Ready to implement <feature>
```

## Merge-back to Main

**Core rule:** Always produce linear history — never create merge commits. Use rebase + `--ff-only`, **never**
`--no-ff`.

`merge.ff = only` is set declaratively in `home-modules/git/*.nix` (see AGENTS.md "Linear History"), so the default
`git merge` already refuses non-fast-forward merges with `fatal: Not possible to fast-forward, aborting.`. The patterns
below use explicit `--ff-only` for clarity and to make intent visible in shell history.

### Single Worktree

When main hasn't moved since the worktree was created, the branch is directly fast-forwardable:

```bash
git switch main
git pull --ff-only       # sync with remote before merging
git merge --ff-only <branch-name>
```

If `--ff-only` refuses, main moved under you — rebase first, then ff-only:

```bash
git switch <branch-name> && git rebase main
git switch main && git merge --ff-only <branch-name>
```

### Multiple Parallel Worktrees

For N branches off the same base (e.g. two worktrees created from the same main commit), merge them sequentially with
rebase + ff-only. First branch ff-merges cleanly; every subsequent branch must rebase onto the new main first.

```bash
# Branch 1 — ff works (main hasn't moved relative to it)
git switch main
git merge --ff-only <branch-1>

# Branch 2 — rebase onto updated main, then ff-only
git switch <branch-2> && git rebase main
git switch main && git merge --ff-only <branch-2>
```

Result: linear history, no merge commits, both feature commits sit one atop the other.

### Worked Example (Anti-Pattern)

This is the bad pattern from the #80/#83/#77 session that motivated this rule — do the opposite:

```bash
# WRONG — creates a real merge commit, breaks linear history, invalid Conventional Commit prefix
git switch main
git merge --no-ff docs/77-agents-grep-rule -m "merge: docs(agents): ..."

# RIGHT — rebase + ff-only, no merge commit
git switch main && git merge --ff-only fix/83-gh-pm-cli-bugs
git switch docs/77-agents-grep-rule && git rebase main
git switch main && git merge --ff-only docs/77-agents-grep-rule
```

### After Merge

Clean up the worktree and its branch:

```bash
git worktree remove ~/.worktrees/<project>/<worktree-name>
git branch -d <branch-name>      # -d refuses if branch not fully merged
```

If `git worktree remove` refuses due to uncommitted changes, inspect with `git -C <path> status` and either commit,
stash, or confirm with `--force`.

## Quick Reference

| Situation | Action | | --- | --- | | `~/.worktrees/` exists | Use it | | Both exist | Use `~/.worktrees/` | | Neither
exists | Check AGENTS.md → Ask user | | Directory not ignored | Add to .gitignore + commit | | Tests fail during
baseline | Report failures + ask | | No package.json/Cargo.toml | Skip dependency install | | Merging one worktree back
| `git merge --ff-only <branch>` (rebase first if refused) | | Merging N parallel worktrees | ff-only first, then
`rebase main` + ff-only each subsequent | | `--ff-only` refused | `git rebase main` on the branch, then retry |

## Common Mistakes

### Skipping ignore verification

- **Problem:** Worktree contents get tracked, pollute git status
- **Fix:** Always use `git check-ignore` before creating project-local worktree

### Assuming directory location

- **Problem:** Creates inconsistency, violates project conventions
- **Fix:** Follow priority: existing > AGENTS.md → ask

### Proceeding with failing tests

- **Problem:** Can't distinguish new bugs from pre-existing issues
- **Fix:** Report failures, get explicit permission to proceed

### Hardcoding setup commands

- **Problem:** Breaks on projects using different tools
- **Fix:** Auto-detect from project files (package.json, etc.)

## Example Workflow

```
I'm using the using-git-worktrees skill to set up an isolated workspace.
[Check ~/.worktrees/ - exists]
[Verify ignored - git check-ignore confirms .worktrees/ is ignored] (if using project-local)
[Create worktree: git worktree add ~/.worktrees/<project>-fix-auth -b feature/fix-auth]
[Run npm install]
[Run npm test - 47 passing]

Worktree ready at /Users/jesse/.worktrees/<project>-fix-auth
Tests passing (47 tests, 0 failures)
Ready to implement auth feature
```

## Red Flags

**Never:**

- Create worktree without verifying it's ignored (project-local)
- Skip baseline test verification
- Proceed with failing tests without asking
- Assume directory location when ambiguous
- Skip AGENTS.md check
- Use `git merge --no-ff` — always rebase + `git merge --ff-only` for linear history
- Use `merge:` as a Conventional Commit type — it's invalid; the merge step itself shouldn't create a commit

**Always:**

- Follow directory priority: existing > AGENTS.md > ask
- Verify directory is ignored for project-local
- Auto-detect and run project setup
- Verify clean test baseline
- Rebase feature branches onto current main, then `git merge --ff-only`
