---
name: using-git-worktrees
description: Use when starting feature work that needs isolation from the current workspace or before executing an implementation plan. Creates an isolated git worktree with safe directory selection and baseline verification.
---

# Using Git Worktrees

## Overview

Git worktrees create isolated workspaces that share the same repository, allowing work on multiple branches
simultaneously without switching the current checkout.

**Core principle:** systematic directory selection + safety verification = reliable isolation.

**Announce at start:** "I'm using the using-git-worktrees skill to set up an isolated workspace."

## Directory Selection Process

Follow this priority order:

### 1. Check Existing Directories

```bash
# Check in priority order
ls -d ~/.worktrees 2>/dev/null # Preferred
ls -d ./.worktrees 2>/dev/null # Alternative
```

**If found:** use that directory. If both exist, `~/.worktrees` wins.

### 2. Check Repository Instructions

```bash
grep -i "worktree.*directory" AGENTS.md 2>/dev/null
grep -i "worktree.*directory" README.md 2>/dev/null
```

**If a preference is specified:** use it without asking.

### 3. Ask User

If no directory exists and no repository instruction specifies a location:

```text
No worktree directory found. Where should I create worktrees?
1. ~/.worktrees/  (global location)
2. .worktrees/    (project-local, hidden)
Which would you prefer?
```

## Safety Verification

### For Project-Local Directories (`./.worktrees`)

**MUST verify the directory is ignored before creating a worktree:**

```bash
git check-ignore -q .worktrees
```

**If NOT ignored:** immediately fix by:

1. Adding `.worktrees/` to `.gitignore`
2. Committing that change
3. Proceeding with worktree creation

**Why critical:** prevents accidentally committing worktree contents to the repository.

### For Global Directories (`~/.worktrees`)

No `.gitignore` verification is needed because the directory lives outside the repository.

## Creation Steps

### 1. Detect Project Name

```bash
project=$(basename "$(git rev-parse --show-toplevel)")
```

### 2. Create Worktree

```bash
case "$LOCATION" in
  "$HOME/.worktrees")
    path="$HOME/.worktrees/$project/$BRANCH_NAME"
    ;;
  ".worktrees"|"./.worktrees")
    path=".worktrees/$BRANCH_NAME"
    ;;
esac

git worktree add "$path" -b "$BRANCH_NAME"
cd "$path"
```

### 3. Run Project Setup

Auto-detect setup from repository instructions (`AGENTS.md`, `README.md`) and package manifests before hardcoding a
command. For example:

- `package.json`: inspect scripts and use the documented package manager (`npm`, `pnpm`, etc.)
- `Cargo.toml`: use Cargo commands
- `pyproject.toml`: use the documented Python environment/bootstrap flow
- `flake.nix`: use the repository's documented Nix checks or dev-shell workflow

Then run the project-appropriate setup command, such as dependency installation, entering a dev shell, or another
bootstrap step.

### 4. Verify Clean Baseline

Run the relevant checks to ensure the worktree starts clean:

```bash
# Examples - use project-appropriate command
npm test
pnpm test
cargo test
dotnet test
nix flake check
```

If the project does not define a clear test/build command, report that and continue only if appropriate.

**If checks fail:** report the failures and ask whether to proceed or investigate.  
**If checks pass:** report that the worktree is ready.

### 5. Report Location

```text
Worktree ready at <path>
Checks passing
Ready to implement <feature>
```

## Quick Reference

| Situation | Action |
| --- | --- |
| `~/.worktrees/` exists | Use it |
| Both exist | Use `~/.worktrees/` |
| Neither exists | Check repository instructions, then ask the user |
| Project-local directory not ignored | Add `.worktrees/` to `.gitignore`, commit, then continue |
| Baseline checks fail | Report failures and ask before proceeding |
| No obvious setup/test command | Report that and use the project’s documented workflow |

## Common Mistakes

### Skipping ignore verification

- **Problem:** worktree contents get tracked and pollute `git status`
- **Fix:** always use `git check-ignore` before creating a project-local worktree

### Assuming directory location

- **Problem:** creates inconsistency and violates project conventions
- **Fix:** follow the priority order: existing directory > repository instructions > ask user

### Proceeding with failing checks

- **Problem:** you can't distinguish new bugs from pre-existing issues
- **Fix:** report failures and get explicit permission to proceed

### Hardcoding setup commands

- **Problem:** breaks on projects using different tooling
- **Fix:** auto-detect setup from repository files and instructions

## Example Workflow

```text
You: I'm using the using-git-worktrees skill to set up an isolated workspace.
[Check ~/.worktrees/ - exists]
[Create worktree: git worktree add ~/.worktrees/<project>/feature/fix-auth -b feature/fix-auth]
[Run project setup]
[Run baseline checks - all passing]

Worktree ready at /home/user/.worktrees/<project>/feature/fix-auth
Checks passing
Ready to implement auth feature
```

## Red Flags

**Never:**

- Create a project-local worktree without verifying `.worktrees/` is ignored
- Skip baseline verification when the project has defined checks
- Proceed with failing checks without asking
- Assume a directory location when the repository instructions are ambiguous

**Always:**

- Follow the directory priority: existing directory > repository instructions > ask user
- Verify `.worktrees/` is ignored for project-local worktrees
- Auto-detect and run the project’s setup steps
- Verify a clean baseline before implementing changes
