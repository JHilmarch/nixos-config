---
name: commit
description: Write clear commit messages using Conventional Commits
allowed-tools: Bash, Read, Glob, Grep
---

# Committing Changes

Make small, atomic commits with clear messages using Conventional Commits.

## Workflow

### 1. Analyze diff

Review the changes before committing:

```bash
# If files are staged, use staged diff
git diff --staged

# If nothing staged, use working tree diff
git diff

# Also check status
git status --porcelain
```

### 2. Stage Files (if needed)

If nothing is staged, or you want to group changes differently:

```bash
# Stage specific files
git add path/to/file1 path/to/file2

# Stage by pattern
git add *.test.*
git add src/components/*

# Interactive staging
git add -p
```

Never commit secrets (.env, credentials.json, private keys).

**No merge commits:** this repo enforces linear history (see AGENTS.md "Linear History"). This skill creates regular
commits on a feature branch — never run `git merge --no-ff` to combine branches. If you need to integrate two branches,
rebase one onto the other and use `git merge --ff-only` (see `/using-git-worktrees` "Merge-back to main"). The `merge:`
prefix is **not** a valid Conventional Commits type.

### 3. Generate Commit Message

Make small, atomic commits - each commit should address one logical change. If your work spans multiple concerns (e.g.,
a refactor and a bug fix), break it into separate commits.

Reference the relevant GitHub issue as a footer (rules in **Issue references** below).

Always create a NEW commit. Never amend unless the user explicitly asks.

#### Commit command format

Use one `-m` flag per **paragraph**. Use `printf '%s\n' 'line1' 'line2'` to wrap body lines at 72 characters within a
single `-m` paragraph.

```bash
# CORRECT: one -m per paragraph, body lines via printf
git commit -m "feat(wsl-cab): add copilot-cli with Azure DevOps" \
  -m "$(printf '%s\n' \
    'Enable the copilot-cli home module in wsl-cab with' \
    'azure-devops-mcp as a runtime input and MCP server entry.' \
    'Add PAT authentication docs to README.')" \
  -m "Closes: #65"

# WRONG: one -m per line (creates separate paragraphs with blank lines)
git commit -m "title" \
  -m "Enable the copilot-cli home module in wsl-cab with" \
  -m "azure-devops-mcp as a runtime input." \
  -m "Add PAT authentication docs to README."
```

NEVER use one `-m` per sentence. That fragments the body into disconnected paragraphs with blank lines between them.
Each `-m` is one paragraph — use `printf` to create real newlines within it.

### 3. Conventional Commit Format

```
<type>(<scope>): <subject>

<body>

<footer>
```

**Constraints:**

- Subject line must be at most **50 characters**
- Body lines must be at most **72 characters**
- Use host or module name as scope (e.g. `orion`, `wsl-cab`, `nfs`, `claude`)

#### Issue references

Always link a commit to its board item (task / bug / story) using a footer keyword:

- **`Refs: #<N>`** — the commit works on the issue but does not finish it. Always include when working from a board item.
- **`Closes: #<N>`** — the commit completes the issue. GitHub closes the issue when the commit lands on the default
  branch.

Use **one footer line per issue** — never comma-separated:

```
# WRONG — GitHub does not reliably parse this
Closes: #1, #2

# RIGHT — one line per issue
Closes: #1
Closes: #2
```

#### Commit Types

- `feat` - New feature
- `fix` - Bug fix
- `docs` - Documentation only
- `style` - Formatting/style (no logic)
- `refactor` - Code refactor (no feature/fix)
- `perf` - Performance improvement
- `test` - Add/update tests
- `build` - Build system/dependencies
- `ci` - CI/config changes
- `chore` - Maintenance/misc
- `revert` - Revert commit

#### Breaking Changes

```
# Exclamation mark after type/scope
feat(orion)!: remove deprecated endpoint

# BREAKING CHANGE footer
feat: allow config to extend other configs

BREAKING CHANGE: `extends` key behavior changed
```
