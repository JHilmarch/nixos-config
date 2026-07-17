---
name: project-manager
description: Plan, refine, and delegate work on a GitHub or Forgejo project board — multi-provider via .project-manager.json config
disable-model-invocation: true
allowed-tools: Bash, Read, Glob, Grep, Skill
---

## How to use the project-manager CLI

Call the packaged `project-manager` command directly — it is on PATH via `pkgs.local.project-manager` (installed on the
orion and p51 hosts only). The packaged wrapper bakes in its own dependencies (`gh` + `jq` for the GitHub backend,
`curl` + `jq` for Forgejo), so it works from any shell.

**Host prerequisite:** the `project-manager` binary is installed on orion and p51 only. On other hosts, this skill
cannot be used.

**Documentation**

```bash
project-manager --help --json
```

**Example:** _count all items in project 2, matching the free-text-search "Ready"_

```bash
project-manager --json count-items 2 "Ready"
```

The CLI requires a `.project-manager.json` config file in the repo root (or explicit `--provider` flags). Read the
config file to determine the default provider, owner, and repo.

## Configuration

All per-repo settings are read from `.project-manager.json` at the git repo root:

- **Provider**: read `default_provider` from `.project-manager.json`. Use `--provider <name>` for non-default providers.
- **Owner**: read `providers.<name>.owner` from `.project-manager.json` — the CLI auto-applies this as the default
  owner.
- **Repository**: read `providers.<name>.repo` from `.project-manager.json` — pass as `owner/repo` to commands that need
  it.
- **Project**: ask the user which project number to use, or list available projects
- **All calls** must use the `--json` flag
- **ID lookups**: use `get-project-id` and `get-content-id` to obtain GraphQL node IDs needed by other commands
- **Field discovery**: use `list-fields` to discover field IDs and option IDs before updating
- Run `--help` on the CLI to see all available commands

Read `owner` and `repo` from `.project-manager.json` for the active provider. The config file is the source of truth —
do NOT auto-detect from git remote.

**Repos without a config file:** if the repo has no `.project-manager.json`, ask the user which provider to use and pass
`--provider <name>` explicitly.

## Provider Selection

The CLI supports two providers. Selection priority: `--provider` flag > config `default_provider` >
`PROJECT_MANAGER_BACKEND` env var > error (no hardcoded default).

| Provider  | Config key | Credentials                                                              | Supports                                                                                               |
| --------- | ---------- | ------------------------------------------------------------------------ | ------------------------------------------------------------------------------------------------------ |
| `github`  | `github`   | `GH_CLI` (from config `providers.github.cli`)                            | **All 21 commands**: project boards, fields, items, updates, reports, stories, tasks                   |
| `forgejo` | `forgejo`  | `FORGEJO_TOKEN` (injected by package) + `FORGEJO_API_BASE` (from config) | **6 commands**: `list-items`, `count-items`, `get-content-id`, `report`, `create-story`, `create-task` |

To use the non-default provider:

```bash
project-manager --provider forgejo --json <command>
```

To use the default provider (from `.project-manager.json`):

```bash
project-manager --json <command>
```

### Forgejo provider notes

- Forgejo 15.0.3 has **no project/board API**, so project-board commands (`list-projects`, `view-project`,
  `create-project`, `list-fields`, `create-field`, `add-item`, `add-item-by-id`, `remove-item`, `update-select`,
  `update-text`, `update-number`, `update-date`, `get-project-id`, `add-to-board`, `set-field`) are rejected with an
  explicit error. Use the GitHub provider for project-board planning.
- `list-items`, `count-items`, and `report` operate on a **repository** (the first positional argument is `owner/repo`
  or just `repo` with `--owner`), not a project number. Pagination uses Forgejo's `page` + `limit` query params;
  `--after` is interpreted as a 1-based page number.
- `create-task`'s third positional argument is interpreted as the **parent issue number** in the same repository; the
  backend attempts to create a Forgejo issue dependency (`POST /repos/{owner}/{repo}/issues/{parent}/dependencies`). If
  dependency linking fails, the task is still created and `linked: false` is reported.
- Output shapes differ slightly from GitHub because Forgejo returns integer issue IDs rather than GraphQL node IDs. The
  CLI maps `id` to a `node_id` string field where possible for consumers that expect the GitHub key name.

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

For operations not supported by the project-manager CLI, use the following:

- **Project board operations** → use `github-project-manager` (classic PAT via the Fish CLI)
- **Other GitHub operations** (issues, PRs, repos, etc.) → use the `github-personal` MCP tools
  - **Fallback for unsupported queries** → use `gh-personal` CLI wrapper
  - **Never use bare `gh`** — always use `gh-personal` (personal) or `gh-work` (work) wrappers instead
