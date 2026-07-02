---
name: project-manager
description: Plan, refine, and delegate work on a GitHub Project board
disable-model-invocation: true
allowed-tools: Bash, Read, Glob, Grep, Skill
---

## How to use the gh-project-manager CLI

Call the packaged `gh-project-manager` command directly — it is on PATH via `pkgs.local.gh-project-manager` (installed
on the p51 and orion hosts). The packaged wrapper bakes in its own `gh` + `jq` dependencies, so it works from any shell.

**Documentation**

```bash
gh-project-manager --help --json
```

**Example:** _count all items in the project 2, matching the free-text-search "Ready"_

```bash
gh-project-manager --json --owner JHilmarch count-items 2 "Ready"
```

## Configuration

- **CLI**: `gh-personal-project-manager` (pass via `--cli gh-personal-project-manager`)
- **Owner**: `JHilmarch` (pass via `--owner JHilmarch`)
- **Repository**: auto-detected via `git -C . remote get-url origin` — extract the `owner/repo` part
- **Project**: ask the user which project number to use, or list available projects
- **All calls** must use the `--json` flag
- **ID lookups**: use `get-project-id` and `get-content-id` to obtain GraphQL node IDs needed by other commands
- **Field discovery**: use `list-fields` to discover field IDs and option IDs before updating
- Run `--help` on the CLI to see all available commands

To auto-detect the repo, run:

```bash
git -C . remote get-url origin | sed 's|.*github.com[/:]||; s|\.git$||'
```

## Planning instructions

1. Ask the user what feature to plan. They can reference an existing issue, file, or describe it freely
1. Ask clarifying questions if the description is vague
1. Create a user story issue with acceptance criteria, context, and out-of-scope sections
1. Propose 3-7 tasks to the user — indicate parallel vs sequential dependencies. Wait for approval
1. Create each task as a sub-issue linked to the story
1. Add all issues to the project board using `add-to-board`, then set fields with `set-field`
1. Present a summary with story link, task table, execution order, and board URL

## Refinement instructions

1. List items in "Backlog" or "Needs Refinement" status on the board
1. For each item, ensure the issue body has: Problem, Proposed Solution, Acceptance Criteria
1. If an issue is too large or vague, propose splitting it into sub-issues
1. Apply labels: one type, one priority, one size
1. Set the Estimate and Priority fields on the board
1. Link dependencies (sub-issues, "blocked by" references)
1. Move refined items to "Ready" status
1. Flag items needing human input (product decisions, ambiguous scope, unclear priority)

## Delegating instructions

1. Pick a "Ready" item from the board
1. Add an assignment brief to the issue body with: key files to start from, what "done" looks like, and how to verify
1. Include relevant context: related issues, code pointers, design decisions already made, constraints
1. Assign the issue and move to "In Progress"

## Guidelines

- Stories focus on user value, not implementation
- Tasks should be completable in one sitting
- Always wait for user approval before creating issues
- Flag ambiguous items rather than guessing during refinement
- Assignment briefs add implementation starting points — the refined issue already has acceptance criteria

## Fallback routines

For operations not supported by the gh-project-manager CLI, use the following:

- **Project board operations** → use `gh-personal-project-manager` (classic PAT via the Fish CLI)
- **Other GitHub operations** (issues, PRs, repos, etc.) → use the `github-personal` MCP tools
  - **Fallback for unsupported queries** → use `gh-personal` CLI wrapper
  - **Never use bare `gh`** — always use `gh-personal` (personal) or `gh-work` (work) wrappers instead
