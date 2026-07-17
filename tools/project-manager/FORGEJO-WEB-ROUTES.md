# Forgejo project board — web-route reference (v15.0.x)

Ground-truth for the Forgejo backend's GUI-emulation operations in [`_backend_forgejo.fish`](./_backend_forgejo.fish).
Forgejo has **no** REST/API v1 project-board endpoints, so board management replays the exact browser (web) form POSTs
the GUI issues — the same approach as `patrickzzz/forgejo-web`.

All routes/forms below are read from Forgejo source tag `v15.0.3` (`routers/web/web.go`, `routers/web/repo/projects.go`,
`services/forms/repo_form.go`, `models/project/{project,column}.go`) and match the live server (15.0.4).

## Authentication

- Web routes require the session cookie **`i_like_gitea`**. A personal access token (`Authorization: token <PAT>`)
  authenticates the **REST API only** and is rejected by web routes — a private repo returns HTTP 404 to any web request
  without a valid session cookie.
- Session is established with a form login: `POST /user/login` — fields `user_name`, `password`, `remember`. The login
  page is CSRF-exempt; the session cookie is set on a successful POST.
- CSRF for state-changing web POSTs uses a **SameSite cookie + `Origin` header** check, **not** a `_csrf` form field.
  Sending `Origin: <base-url>` on POST/PUT/DELETE satisfies it. (No hidden `_csrf` input is present in the project
  forms.)

Because the GUI needs a username+password session, the backend reads `FORGEJO_WEB_USER` / `FORGEJO_WEB_PASS` (a
dedicated bot account), distinct from the REST `FORGEJO_TOKEN`.

## Repo-level routes (base `/{owner}/{repo}/projects`)

| Operation           | Method | Path                                | Body                                             |
| ------------------- | ------ | ----------------------------------- | ------------------------------------------------ |
| list projects       | GET    | `/projects`                         | — (HTML)                                         |
| view project        | GET    | `/projects/{id}`                    | — (HTML)                                         |
| create project      | POST   | `/projects/new`                     | `title`, `content`, `template_type`, `card_type` |
| edit project        | POST   | `/projects/{id}/edit`               | same as create                                   |
| open / close        | POST   | `/projects/{id}/open` \| `/close`   | —                                                |
| delete project      | POST   | `/projects/{id}/delete`             | —                                                |
| add column          | POST   | `/projects/{id}`                    | `title`, `sorting`, `color` (JSON response)      |
| edit column         | PUT    | `/projects/{id}/{columnID}`         | `title`, `sorting`, `color`                      |
| delete column       | DELETE | `/projects/{id}/{columnID}`         | —                                                |
| set default column  | POST   | `/projects/{id}/{columnID}/default` | —                                                |
| reorder columns     | POST   | `/projects/{id}/move`               | `{"columns":[{"columnID":N,"sorting":N}]}`       |
| move issue → column | POST   | `/projects/{id}/{columnID}/move`    | `{"issues":[{"issueID":N,"sorting":N}]}`         |

Issue ↔ project attach/detach is an **issue** route, not a project route:

| Operation                 | Method | Path                              | Body                                                 |
| ------------------------- | ------ | --------------------------------- | ---------------------------------------------------- |
| add/remove issue on board | POST   | `/{owner}/{repo}/issues/projects` | `issue_ids` (comma-sep), `id` (project; `0` removes) |

## Org / user-level routes

Identical shape under `/{username}/-/projects` (note the `/-/` separator). Handlers are `org.*` instead of `repo.*`.
This backend targets repo-level boards (`.project-manager.json` sets `owner`/`repo`); org-level is out of scope for this
pass.

## Form field values

`CreateProjectForm` (`services/forms/repo_form.go`):

- `title` — required, ≤100 chars
- `content` — optional description
- `template_type` — `0`=None (default), `1`=BasicKanban, `2`=BugTriage
- `card_type` — `0`=TextOnly (default), `1`=ImagesAndText

`EditProjectColumnForm`:

- `title` — required, ≤100 chars
- `sorting` — int8
- `color` — ≤7 chars, e.g. `#00aabb`

## HTML scraping (no JSON list endpoint)

Project/column/issue IDs are read from the rendered HTML data-attributes:

- project id — `data-project="<id>"` on the board container
- column id — `data-id="<id>"` on `.project-column`
- issue/card id — `data-issue="<id>"` on `.issue-card`

The projects **list** page rows link to `/{owner}/{repo}/projects/{id}`; the id is parsed from that href and the visible
title/state alongside it.
