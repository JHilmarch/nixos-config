______________________________________________________________________

## name: commit description: Write clear commit messages using Conventional Commits allowed-tools: Bash, Read, Glob, Grep

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

### 3. Generate Commit Message

Make small, atomic commits - each commit should address one logical change. If your work spans multiple concerns (e.g.,
a refactor and a bug fix), break it into separate commits.

If applicable: Reference the relevant GitHub issue as a footer (`Closes #123` or `Refs #123`).

Always create a NEW commit. Never amend unless the user explicitly asks.

#### Commit command format

Use one `-m` flag per **paragraph**. Within each paragraph, wrap lines with literal `\n` at 72 characters.

```bash
# CORRECT: one -m per paragraph, lines wrapped at 72 chars
git commit -m "feat(wsl-cab): add copilot-cli with Azure DevOps" \
  -m "Enable the copilot-cli home module in wsl-cab with\nazure-devops-mcp as a runtime input and MCP server entry.\nAdd PAT authentication docs to README." \
  -m "Closes #65"

# WRONG: one -m per line (creates separate paragraphs)
git commit -m "title" \
  -m "Enable the copilot-cli home module in wsl-cab with" \
  -m "azure-devops-mcp as a runtime input." \
  -m "Add PAT authentication docs to README."
```

NEVER use one `-m` per sentence. That fragments the body into disconnected lines. Each `-m` is a paragraph — wrap within
it.

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
