#!/usr/bin/env fish
# @fish-lsp-disable 4004
#
# gh-project-manager — GitHub Projects v2 management & feature planning CLI
#
# Usage:
#   fish tools/gh-project-manager/gh-project-manager.fish [OPTIONS] <command> [ARGS]
#
# Options:
#   --json              Output structured JSON (suppresses all logging)
#   --owner <owner>     Default owner (or GH_PROJECT_OWNER env var)
#   --cli <cmd>         GitHub CLI command (default: gh-personal-project-manager, or GH_CLI env var)
#   --help              Show this help message (--help --json for machine-readable)
#
# Environment:
#   PROJECT_MANAGER_BACKEND   Forge backend: github (default) | forgejo
#   FORGEJO_TOKEN             Required for forgejo backend. PAT for Authorization: token <PAT>
#   FORGEJO_API_BASE          Optional forgejo base URL (default: https://forge.fileshare.se/api/v1)
#
# Backend parity:
#   GitHub backend supports all commands (Projects v2). Forgejo backend supports
#   issue/label/milestone operations only: list-items, count-items, get-content-id,
#   report, create-story, create-task. Project-board ops are honestly rejected.
#
# Commands:
#   Project operations:
#     list-projects [owner]              List projects
#     view-project <number> [owner]      View project details
#     create-project <title> [owner]     Create a project
#   Field operations:
#     list-fields <number> [owner]       List fields with IDs and options
#     create-field <number> <name> <type> [owner] [options...]
#   Item operations:
#     list-items <number> [--query <text>] [--first <n>] [--all] [--after <cursor>] [owner]
#                                       List items with pagination and filtering
#     count-items <number> [query] [owner]
#                                       Count items (optionally filtered)
#     add-item <number> <url> [owner]    Add issue/PR by URL
#     add-item-by-id <project-id> <content-id>
#     remove-item <project-id> <item-id> Remove item from project
#   Field updates:
#     update-select <project-id> <item-id> <field-id> <option-id>
#     update-text <project-id> <item-id> <field-id> <text>
#     update-number <project-id> <item-id> <field-id> <number>
#     update-date <project-id> <item-id> <field-id> <date>
#   ID lookups:
#     get-project-id <number> [owner]    Get project node ID
#     get-content-id <repo> <number>     Get issue/PR node ID
#   Reports:
#     report <number> [owner]            Project status report
#   Story & task creation (body from stdin):
#     create-story <repo> <title> [--label <label>]
#     create-task <repo> <title> <parent-node-id> [--label <label>]
#   Board operations:
#     add-to-board <project-number> <node-id> [node-id ...]
#     set-field <project-id> <item-id> <field-name> <option-name>

set -g JSON_MODE false
set -q GH_CLI; or set -g GH_CLI gh-personal-project-manager
set -q GH_PROJECT_OWNER; and set -g OWNER $GH_PROJECT_OWNER; or set -g OWNER ""
set -q PROJECT_MANAGER_BACKEND; or set -g PROJECT_MANAGER_BACKEND github
set -g _OWNER_TYPE ""

set -l script_dir (dirname (status filename))
source "$script_dir/../common/log.fish"
source "$script_dir/_backend_github.fish"
source "$script_dir/_backend_forgejo.fish"

# ── Helpers ───────────────────────────────────────────────────────────────────

function resolve_owner
    set -l override "$argv[1]"
    if test -n "$override"
        echo "$override"
    else if test -n "$OWNER"
        echo "$OWNER"
    else
        die "Owner not specified. Use --owner or set GH_PROJECT_OWNER."
    end
end

# Prepend OWNER/ to a bare repo name. `gh` requires OWNER/REPO for every --repo flag.
function normalize_repo
    set -l repo $argv[1]
    if string match -q '*/*' -- "$repo"
        echo "$repo"
        return
    end
    if test -z "$OWNER"
        die "Repository '$repo' needs an owner prefix and no --owner is set. Pass 'OWNER/REPO' or use --owner."
    end
    echo "$OWNER/$repo"
end
# ── Backend dispatch ──────────────────────────────────────────────────────────
# One _op_<name> wrapper per operation routes to the active backend
# implementation. Forgejo cases call _backend_forgejo_<name>; GitHub cases call
# _backend_github_<name>. cmd_* functions and the dispatch table below stay
# untouched when adding new backends.

function _op_list_projects
    switch $PROJECT_MANAGER_BACKEND
        case github
            _backend_github_list_projects $argv
        case forgejo
            _backend_forgejo_list_projects $argv
        case '*'
            die "Unknown PROJECT_MANAGER_BACKEND: $PROJECT_MANAGER_BACKEND (expected github or forgejo)"
    end
end

function _op_view_project
    switch $PROJECT_MANAGER_BACKEND
        case github
            _backend_github_view_project $argv
        case forgejo
            _backend_forgejo_view_project $argv
        case '*'
            die "Unknown PROJECT_MANAGER_BACKEND: $PROJECT_MANAGER_BACKEND (expected github or forgejo)"
    end
end

function _op_create_project
    switch $PROJECT_MANAGER_BACKEND
        case github
            _backend_github_create_project $argv
        case forgejo
            _backend_forgejo_create_project $argv
        case '*'
            die "Unknown PROJECT_MANAGER_BACKEND: $PROJECT_MANAGER_BACKEND (expected github or forgejo)"
    end
end

function _op_list_fields
    switch $PROJECT_MANAGER_BACKEND
        case github
            _backend_github_list_fields $argv
        case forgejo
            _backend_forgejo_list_fields $argv
        case '*'
            die "Unknown PROJECT_MANAGER_BACKEND: $PROJECT_MANAGER_BACKEND (expected github or forgejo)"
    end
end

function _op_create_field
    switch $PROJECT_MANAGER_BACKEND
        case github
            _backend_github_create_field $argv
        case forgejo
            _backend_forgejo_create_field $argv
        case '*'
            die "Unknown PROJECT_MANAGER_BACKEND: $PROJECT_MANAGER_BACKEND (expected github or forgejo)"
    end
end

function _op_list_items
    switch $PROJECT_MANAGER_BACKEND
        case github
            _backend_github_list_items $argv
        case forgejo
            _backend_forgejo_list_items $argv
        case '*'
            die "Unknown PROJECT_MANAGER_BACKEND: $PROJECT_MANAGER_BACKEND (expected github or forgejo)"
    end
end

function _op_count_items
    switch $PROJECT_MANAGER_BACKEND
        case github
            _backend_github_count_items $argv
        case forgejo
            _backend_forgejo_count_items $argv
        case '*'
            die "Unknown PROJECT_MANAGER_BACKEND: $PROJECT_MANAGER_BACKEND (expected github or forgejo)"
    end
end

function _op_add_item
    switch $PROJECT_MANAGER_BACKEND
        case github
            _backend_github_add_item $argv
        case forgejo
            _backend_forgejo_add_item $argv
        case '*'
            die "Unknown PROJECT_MANAGER_BACKEND: $PROJECT_MANAGER_BACKEND (expected github or forgejo)"
    end
end

function _op_add_item_by_id
    switch $PROJECT_MANAGER_BACKEND
        case github
            _backend_github_add_item_by_id $argv
        case forgejo
            _backend_forgejo_add_item_by_id $argv
        case '*'
            die "Unknown PROJECT_MANAGER_BACKEND: $PROJECT_MANAGER_BACKEND (expected github or forgejo)"
    end
end

function _op_remove_item
    switch $PROJECT_MANAGER_BACKEND
        case github
            _backend_github_remove_item $argv
        case forgejo
            _backend_forgejo_remove_item $argv
        case '*'
            die "Unknown PROJECT_MANAGER_BACKEND: $PROJECT_MANAGER_BACKEND (expected github or forgejo)"
    end
end

function _op_update_select
    switch $PROJECT_MANAGER_BACKEND
        case github
            _backend_github_update_select $argv
        case forgejo
            _backend_forgejo_update_select $argv
        case '*'
            die "Unknown PROJECT_MANAGER_BACKEND: $PROJECT_MANAGER_BACKEND (expected github or forgejo)"
    end
end

function _op_update_text
    switch $PROJECT_MANAGER_BACKEND
        case github
            _backend_github_update_text $argv
        case forgejo
            _backend_forgejo_update_text $argv
        case '*'
            die "Unknown PROJECT_MANAGER_BACKEND: $PROJECT_MANAGER_BACKEND (expected github or forgejo)"
    end
end

function _op_update_number
    switch $PROJECT_MANAGER_BACKEND
        case github
            _backend_github_update_number $argv
        case forgejo
            _backend_forgejo_update_number $argv
        case '*'
            die "Unknown PROJECT_MANAGER_BACKEND: $PROJECT_MANAGER_BACKEND (expected github or forgejo)"
    end
end

function _op_update_date
    switch $PROJECT_MANAGER_BACKEND
        case github
            _backend_github_update_date $argv
        case forgejo
            _backend_forgejo_update_date $argv
        case '*'
            die "Unknown PROJECT_MANAGER_BACKEND: $PROJECT_MANAGER_BACKEND (expected github or forgejo)"
    end
end

function _op_get_project_id
    switch $PROJECT_MANAGER_BACKEND
        case github
            _backend_github_get_project_id $argv
        case forgejo
            _backend_forgejo_get_project_id $argv
        case '*'
            die "Unknown PROJECT_MANAGER_BACKEND: $PROJECT_MANAGER_BACKEND (expected github or forgejo)"
    end
end

function _op_get_content_id
    switch $PROJECT_MANAGER_BACKEND
        case github
            _backend_github_get_content_id $argv
        case forgejo
            _backend_forgejo_get_content_id $argv
        case '*'
            die "Unknown PROJECT_MANAGER_BACKEND: $PROJECT_MANAGER_BACKEND (expected github or forgejo)"
    end
end

function _op_report
    switch $PROJECT_MANAGER_BACKEND
        case github
            _backend_github_report $argv
        case forgejo
            _backend_forgejo_report $argv
        case '*'
            die "Unknown PROJECT_MANAGER_BACKEND: $PROJECT_MANAGER_BACKEND (expected github or forgejo)"
    end
end

function _op_create_story
    switch $PROJECT_MANAGER_BACKEND
        case github
            _backend_github_create_story $argv
        case forgejo
            _backend_forgejo_create_story $argv
        case '*'
            die "Unknown PROJECT_MANAGER_BACKEND: $PROJECT_MANAGER_BACKEND (expected github or forgejo)"
    end
end

function _op_create_task
    switch $PROJECT_MANAGER_BACKEND
        case github
            _backend_github_create_task $argv
        case forgejo
            _backend_forgejo_create_task $argv
        case '*'
            die "Unknown PROJECT_MANAGER_BACKEND: $PROJECT_MANAGER_BACKEND (expected github or forgejo)"
    end
end

function _op_add_to_board
    switch $PROJECT_MANAGER_BACKEND
        case github
            _backend_github_add_to_board $argv
        case forgejo
            _backend_forgejo_add_to_board $argv
        case '*'
            die "Unknown PROJECT_MANAGER_BACKEND: $PROJECT_MANAGER_BACKEND (expected github or forgejo)"
    end
end

function _op_set_field
    switch $PROJECT_MANAGER_BACKEND
        case github
            _backend_github_set_field $argv
        case forgejo
            _backend_forgejo_set_field $argv
        case '*'
            die "Unknown PROJECT_MANAGER_BACKEND: $PROJECT_MANAGER_BACKEND (expected github or forgejo)"
    end
end

function _op_check_prerequisites
    switch $PROJECT_MANAGER_BACKEND
        case github
            _backend_github_check_prerequisites $argv
        case forgejo
            _backend_forgejo_check_prerequisites $argv
        case '*'
            die "Unknown PROJECT_MANAGER_BACKEND: $PROJECT_MANAGER_BACKEND (expected github or forgejo)"
    end
end
# ── Commands — thin CLI layer delegating to the active backend ────────────────

function cmd_list_projects
    _op_list_projects $argv
end

function cmd_view_project
    _op_view_project $argv
end

function cmd_create_project
    _op_create_project $argv
end

function cmd_list_fields
    _op_list_fields $argv
end

function cmd_create_field
    _op_create_field $argv
end

function cmd_list_items
    _op_list_items $argv
end

function cmd_count_items
    _op_count_items $argv
end

function cmd_add_item
    _op_add_item $argv
end

function cmd_add_item_by_id
    _op_add_item_by_id $argv
end

function cmd_remove_item
    _op_remove_item $argv
end

function cmd_update_select
    _op_update_select $argv
end

function cmd_update_text
    _op_update_text $argv
end

function cmd_update_number
    _op_update_number $argv
end

function cmd_update_date
    _op_update_date $argv
end

function cmd_get_project_id
    _op_get_project_id $argv
end

function cmd_get_content_id
    _op_get_content_id $argv
end

function cmd_report
    _op_report $argv
end

function cmd_create_story
    _op_create_story $argv
end

function cmd_create_task
    _op_create_task $argv
end

function cmd_add_to_board
    _op_add_to_board $argv
end

function cmd_set_field
    _op_set_field $argv
end
# ── Help ──────────────────────────────────────────────────────────────────────

function show_help
    if test "$JSON_MODE" = true
        echo '{}' | jq '{
            name: "gh-project-manager",
            description: "GitHub Projects v2 management & feature planning CLI",
            commands: [
                {name: "list-projects", params: ["[owner]"], description: "List projects for an owner"},
                {name: "view-project", params: ["<number>", "[owner]"], description: "View project details"},
                {name: "create-project", params: ["<title>", "[owner]"], description: "Create a new project"},
                {name: "list-fields", params: ["<number>", "[owner]"], description: "List fields with IDs and options"},
                {name: "create-field", params: ["<number>", "<name>", "<type>", "[owner]", "[options...]"], description: "Create a field"},
                {name: "list-items", params: ["<number>", "[--query <text>]", "[--first <n>]", "[--all]", "[--after <cursor>]", "[owner]"], description: "List items with pagination and optional server-side filter"},
                {name: "count-items", params: ["<number>", "[query]", "[owner]"], description: "Count items (optionally filtered by query)"},
                {name: "add-item", params: ["<number>", "<url>", "[owner]"], description: "Add issue/PR by URL"},
                {name: "add-item-by-id", params: ["<project-id>", "<content-id>"], description: "Add item by GraphQL node IDs"},
                {name: "remove-item", params: ["<project-id>", "<item-id>"], description: "Remove item from project"},
                {name: "update-select", params: ["<project-id>", "<item-id>", "<field-id>", "<option-id>"], description: "Update single select field"},
                {name: "update-text", params: ["<project-id>", "<item-id>", "<field-id>", "<text>"], description: "Update text field"},
                {name: "update-number", params: ["<project-id>", "<item-id>", "<field-id>", "<number>"], description: "Update number field"},
                {name: "update-date", params: ["<project-id>", "<item-id>", "<field-id>", "<date>"], description: "Update date field"},
                {name: "get-project-id", params: ["<number>", "[owner]"], description: "Get project node ID from number"},
                {name: "get-content-id", params: ["<repo>", "<number>"], description: "Get issue/PR node ID"},
                {name: "report", params: ["<number>", "[owner]"], description: "Project status report"},
                {name: "create-story", params: ["<repo>", "<title>", "[--label <label>]"], description: "Create a user story issue (body from stdin)"},
                {name: "create-task", params: ["<repo>", "<title>", "<parent-node-id>", "[--label <label>]"], description: "Create a task linked as sub-issue (body from stdin)"},
                {name: "add-to-board", params: ["<project-number>", "<node-id>", "[node-id ...]"], description: "Add items to a project board"},
                {name: "set-field", params: ["<project-id>", "<item-id>", "<field-name>", "<option-name>"], description: "Set a single-select field value"}
            ],
            global_options: [
                {name: "--json", description: "Output structured JSON (suppresses all other output)"},
                {name: "--owner <owner>", description: "Default owner (or GH_PROJECT_OWNER env var)"},
                {name: "--cli <cmd>", description: "GitHub CLI command (default: gh-personal-project-manager, or GH_CLI env var)"},
                {name: "--help", description: "Show this help (--help --json for machine-readable)"}
            ]
        }'
    else
        echo "gh-project-manager — GitHub Projects v2 management & feature planning CLI"
        echo ""
        echo "Usage: fish tools/gh-project-manager/gh-project-manager.fish [OPTIONS] <command> [ARGS]"
        echo ""
        echo "Options:"
        echo "  --json              Output structured JSON (suppresses all logging)"
        echo "  --owner <owner>     Default owner (or GH_PROJECT_OWNER env var)"
        echo "  --cli <cmd>         GitHub CLI command (default: gh-personal-project-manager, or GH_CLI env var)"
        echo "  --help              Show this help message (--help --json for machine-readable)"
        echo ""
        echo "Project operations:"
        echo "  list-projects [owner]"
        echo "  view-project <number> [owner]"
        echo "  create-project <title> [owner]"
        echo ""
        echo "Field operations:"
        echo "  list-fields <number> [owner]"
        echo "  create-field <number> <name> <type> [owner] [options...]"
        echo "    Types: TEXT, SINGLE_SELECT, NUMBER, DATE, ITERATION"
        echo "    Options (for SINGLE_SELECT): High,Medium,Low"
        echo ""
        echo "Item operations:"
        echo "  list-items <number> [options] [owner]"
        echo "    Options: --query <text>  Server-side filter (matches title, body, field values)"
        echo "             --first <n>     Items per page (default: 100)"
        echo "             --all           Fetch all pages automatically"
        echo "             --after <cursor> Resume from a previous endCursor"
        echo "  count-items <number> [query] [owner]"
        echo "  add-item <number> <issue-url> [owner]"
        echo "  add-item-by-id <project-id> <content-node-id>"
        echo "  remove-item <project-id> <item-id>"
        echo ""
        echo "Field updates (GraphQL):"
        echo "  update-select <project-id> <item-id> <field-id> <option-id>"
        echo "  update-text   <project-id> <item-id> <field-id> <text>"
        echo "  update-number <project-id> <item-id> <field-id> <number>"
        echo "  update-date   <project-id> <item-id> <field-id> <date>"
        echo ""
        echo "ID lookups:"
        echo "  get-project-id <number> [owner]"
        echo "  get-content-id <repo> <issue-number>"
        echo ""
        echo "Reports:"
        echo "  report <number> [owner]"
        echo ""
        echo "Story & task creation (body from stdin):"
        echo "  echo \"\$body\" | fish tools/gh-project-manager/gh-project-manager.fish create-story <repo> <title> [--label <label>]"
        echo "  echo \"\$body\" | fish tools/gh-project-manager/gh-project-manager.fish create-task <repo> <title> <parent-node-id> [--label <label>]"
        echo ""
        echo "Board operations:"
        echo "  fish tools/gh-project-manager/gh-project-manager.fish add-to-board <project-number> <node-id> [node-id ...]"
        echo "  fish tools/gh-project-manager/gh-project-manager.fish set-field <project-id> <item-id> <field-name> <option-name>"
        echo ""
        echo "Environment:"
        echo "  GH_PROJECT_OWNER    Default owner"
        echo "  GH_CLI              GitHub CLI command (default: gh-personal-project-manager)"
    end
end
# ── Argument parsing ─────────────────────────────────────────────────────────

# Pre-scan for --json so --help --json works regardless of argument order
if contains -- --json $argv
    set -g JSON_MODE true
end

# Extract global flags manually to preserve subcommand flags like --first, --query, --all, --after
set -l _remaining_args
set -l i 1
while test $i -le (count $argv)
    switch $argv[$i]
        case --json -- -j
            set -g JSON_MODE true
        case --owner
            set i (math $i + 1)
            set -g OWNER $argv[$i]
        case --cli
            set i (math $i + 1)
            set -g GH_CLI $argv[$i]
        case --help -- -h
            show_help
            exit 0
        case '*'
            set -a _remaining_args $argv[$i]
    end
    set i (math $i + 1)
end
set argv $_remaining_args

# ── Prerequisites ─────────────────────────────────────────────────────────────

_op_check_prerequisites

# ── Command dispatch ─────────────────────────────────────────────────────────

if test (count $argv) -lt 1
    show_help
    exit 0
end

set -l command $argv[1]
set -e argv[1]

switch $command
    case list-projects
        cmd_list_projects $argv
    case view-project
        test (count $argv) -lt 1; and die "Usage: view-project <number> [owner]"
        cmd_view_project $argv
    case create-project
        test (count $argv) -lt 1; and die "Usage: create-project <title> [owner]"
        cmd_create_project $argv

    case list-fields
        test (count $argv) -lt 1; and die "Usage: list-fields <number> [owner]"
        cmd_list_fields $argv
    case create-field
        test (count $argv) -lt 3; and die "Usage: create-field <number> <name> <type> [owner] [options...]"
        cmd_create_field $argv

    case list-items
        test (count $argv) -lt 1; and die "Usage: list-items <number> [--query <text>] [--first <n>] [--all] [owner]"
        cmd_list_items $argv
    case count-items
        test (count $argv) -lt 1; and die "Usage: count-items <number> [query] [owner]"
        cmd_count_items $argv
    case remove-item
        test (count $argv) -lt 2; and die "Usage: remove-item <project-id> <item-id>"
        cmd_remove_item $argv
    case add-item-by-id
        test (count $argv) -lt 2; and die "Usage: add-item-by-id <project-id> <content-id>"
        cmd_add_item_by_id $argv
    case add-item
        test (count $argv) -lt 2; and die "Usage: add-item <number> <url> [owner]"
        cmd_add_item $argv

    case update-select
        test (count $argv) -lt 4; and die "Usage: update-select <project-id> <item-id> <field-id> <option-id>"
        cmd_update_select $argv
    case update-text
        test (count $argv) -lt 4; and die "Usage: update-text <project-id> <item-id> <field-id> <text>"
        cmd_update_text $argv
    case update-number
        test (count $argv) -lt 4; and die "Usage: update-number <project-id> <item-id> <field-id> <number>"
        cmd_update_number $argv
    case update-date
        test (count $argv) -lt 4; and die "Usage: update-date <project-id> <item-id> <field-id> <date>"
        cmd_update_date $argv

    case get-project-id
        test (count $argv) -lt 1; and die "Usage: get-project-id <number> [owner]"
        cmd_get_project_id $argv
    case get-content-id
        test (count $argv) -lt 2; and die "Usage: get-content-id <repo> <number>"
        cmd_get_content_id $argv

    case report
        test (count $argv) -lt 1; and die "Usage: report <number> [owner]"
        cmd_report $argv

    case create-story
        test (count $argv) -lt 2; and die "Usage: create-story <repo> <title> [--label <label>]"
        cmd_create_story $argv
    case create-task
        test (count $argv) -lt 3; and die "Usage: create-task <repo> <title> <parent-node-id> [--label <label>]"
        cmd_create_task $argv
    case add-to-board
        test (count $argv) -lt 2; and die "Usage: add-to-board <project-number> <node-id> [node-id ...]"
        cmd_add_to_board $argv
    case set-field
        test (count $argv) -lt 4; and die "Usage: set-field <project-id> <item-id> <field-name> <option-name>"
        cmd_set_field $argv

    case '*'
        die "Unknown command: $command. Run with --help for usage."
end
exit 0
