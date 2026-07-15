# @fish-lsp-disable 4004
#
# _backend_forgejo.fish — Forgejo REST implementation of gh-project-manager operations
#
# Sourced by gh-project-manager.fish; never run directly. The _op_* dispatchers
# in the main script route here when PROJECT_MANAGER_BACKEND=forgejo.
#
# Ground-truth API: Forgejo 15.0.3 at https://forge.fileshare.se/api/v1
# (live Swagger saved at /tmp/opencode/forgejo-swagger.json). This version has
# NO project/board/kanban API endpoints — project-board operations are honestly
# rejected. Implementable operations map to issues, labels, milestones, and
# issue dependencies.
#
# Env vars:
#   FORGEJO_TOKEN     Required. Personal access token for Authorization header.
#   FORGEJO_API_BASE  Optional. Defaults to https://forge.fileshare.se/api/v1

set -q FORGEJO_API_BASE; or set -g FORGEJO_API_BASE "https://forge.fileshare.se/api/v1"
set -q FORGEJO_TOKEN; or set -g FORGEJO_TOKEN ""

# ── Shared Forgejo helpers ────────────────────────────────────────────────────

function _backend_forgejo_no_projects
    set -l op "$argv[1]"
    die "Forgejo backend: $op requires GitHub Projects v2, which is not available in Forgejo 15.0.3 (no project/board API in live swagger). Use GitHub backend for project-board operations."
end

function _backend_forgejo_check_prerequisites
    not command -v curl >/dev/null 2>&1; and die "curl not found in PATH."
    test -z "$FORGEJO_TOKEN"; and die "FORGEJO_TOKEN not set (required for PROJECT_MANAGER_BACKEND=forgejo)."
end

function _backend_forgejo_split_repo
    set -l repo (normalize_repo "$argv[1]")
    set -l parts (string split '/' "$repo")
    printf '%s\n%s' "$parts[1]" "$parts[2]"
end

function _backend_forgejo_api_get
    set -l path "$argv[1]"
    set -e argv[1]
    set -l raw (curl -sS -G -w "\n%{http_code}" -H "Authorization: token $FORGEJO_TOKEN" \
        -H "Accept: application/json" \
        "$FORGEJO_API_BASE$path" $argv)
    set -l parts (string split \n -- "$raw")
    set -l http_code $parts[-1]
    if test -n "$http_code"; and test "$http_code" -ge 400 2>/dev/null
        die "Forgejo API request to $path failed (HTTP $http_code). Check FORGEJO_TOKEN scopes (needs read/write for issues + repository)."
    end
    string join \n -- $parts[1..-2]
end

function _backend_forgejo_api_post
    set -l path "$argv[1]"
    set -l payload "$argv[2]"
    set -l raw (curl -sS -X POST -w "\n%{http_code}" -H "Authorization: token $FORGEJO_TOKEN" \
        -H "Accept: application/json" \
        -H "Content-Type: application/json" \
        -d "$payload" \
        "$FORGEJO_API_BASE$path")
    set -l parts (string split \n -- "$raw")
    set -l http_code $parts[-1]
    if test -n "$http_code"; and test "$http_code" -ge 400 2>/dev/null
        die "Forgejo API request to $path failed (HTTP $http_code). Check FORGEJO_TOKEN scopes (needs read/write for issues + repository)."
    end
    string join \n -- $parts[1..-2]
end

# Ensure a label exists in the repo, creating it with a default color if needed.
# Returns the numeric label id on stdout.
function _backend_forgejo_ensure_label
    set -l repo (normalize_repo "$argv[1]")
    set -l label_name "$argv[2]"

    set -l parts (string split '/' "$repo")
    set -l owner "$parts[1]"
    set -l repo_name "$parts[2]"

    set -l label_json (_backend_forgejo_api_get "/repos/$owner/$repo_name/labels" \
        --data-urlencode "limit=100" \
        | jq --arg name "$label_name" '[.[] | select(.name == $name)][0]')

    if test -n "$label_json" -a "$label_json" != null
        echo "$label_json" | jq -r '.id'
        return 0
    end

    set -l body (echo '{}' | jq --arg name "$label_name" --arg color "#00aabb" \
        '{name: $name, color: $color}')
    set -l create (_backend_forgejo_api_post "/repos/$owner/$repo_name/labels" "$body")
    set -l label_id (echo "$create" | jq -r '.id // empty')

    if test -n "$label_id" -a "$label_id" != null
        log_info "Created label '$label_name' in $repo"
        echo "$label_id"
        return 0
    end

    die "Failed to create label '$label_name' in $repo: $create"
end

# Normalize a repo argument. If owner override is supplied and the repo is bare,
# prepend the override instead of the global OWNER.
function _backend_forgejo_normalize_repo_with_owner
    set -l repo "$argv[1]"
    set -l owner_override "$argv[2]"

    if string match -q '*/*' -- "$repo"
        echo "$repo"
        return
    end

    if test -n "$owner_override"
        echo "$owner_override/$repo"
    else
        normalize_repo "$repo"
    end
end

# Build a JSON issue payload for POST /repos/{owner}/{repo}/issues.
# Arguments: title body label_id_list
function _backend_forgejo_build_issue_body
    set -l title "$argv[1]"
    set -l body "$argv[2]"
    set -l label_ids "$argv[3]"

    echo '{}' | jq --arg title "$title" --arg body "$body" \
        --argjson labels "$label_ids" \
        '{title: $title, body: $body, labels: $labels}'
end

# Read X-Total-Count from a curl -D header file.
function _backend_forgejo_total_from_headers
    set -l header_file "$argv[1]"
    if test -f "$header_file"
        set -l matches (string match -ri '^[Xx]-[Tt]otal-[Cc]ount:\s*([0-9]+)' <"$header_file")
        if test (count $matches) -ge 2
            echo "$matches[2]"
            return 0
        end
    end
    return 1
end

# Read Link header for rel=next.
function _backend_forgejo_has_next_page
    set -l header_file "$argv[1]"
    if test -f "$header_file"
        string match -ri '^[Ll]ink:.*rel="next"' <"$header_file" >/dev/null
        return $status
    end
    return 1
end

# Map a single Forgejo issue JSON object to the shared item shape.
function _backend_forgejo_issue_to_item
    jq '{
        id,
        number,
        title,
        state,
        url: .html_url,
        fields: {}
    }'
end

# Create a labeled issue. Forwards --label flags (if any) via flag_start.
# Returns the created issue JSON object.
function _backend_forgejo_create_labeled_issue
    set -l repo (normalize_repo $argv[1])
    set -l title $argv[2]
    set -l default_label $argv[3]
    set -l flag_start $argv[4]

    set -l label "$default_label"
    set -l i $flag_start
    while test $i -le (count $argv)
        switch $argv[$i]
            case --label='*'
                set label (string replace -- '--label=' '' $argv[$i])
            case --label
                set i (math $i + 1)
                set label $argv[$i]
        end
        set i (math $i + 1)
    end

    set -l body_file (mktemp)
    cat >$body_file
    if not test -s $body_file
        rm $body_file
        die "Body is empty. Pipe content to stdin."
    end

    set -l body_text (cat "$body_file")
    rm $body_file

    set -l label_id (_backend_forgejo_ensure_label "$repo" "$label")
    set -l label_ids (echo "[]" | jq --argjson id "$label_id" '. + [$id]')

    set -l parts (string split '/' "$repo")
    set -l payload (_backend_forgejo_build_issue_body "$title" "$body_text" "$label_ids")
    set -l result (_backend_forgejo_api_post "/repos/$parts[1]/$parts[2]/issues" "$payload")

    set -l issue_number (echo "$result" | jq -r '.number // empty')
    if test -z "$issue_number" -o "$issue_number" = null
        die "Failed to create issue in $repo: $result"
    end

    echo "$result"
end

# Try to link child issue as a dependency of parent issue (same repo).
# Parent is interpreted as an issue number/index in the same repo.
# Returns "true" on success, "false" otherwise.
function _backend_forgejo_link_dependency
    set -l repo (normalize_repo "$argv[1]")
    set -l parent_number "$argv[2]"
    set -l child_number "$argv[3]"

    set -l parts (string split '/' "$repo")
    set -l owner "$parts[1]"
    set -l repo_name "$parts[2]"

    set -l body (echo '{}' | jq --arg owner "$owner" --arg repo "$repo_name" \
        --argjson index "$child_number" \
        '{owner: $owner, repo: $repo, index: $index}')

    set -l linked false
    if curl -sS -X POST -H "Authorization: token $FORGEJO_TOKEN" \
            -H "Accept: application/json" \
            -H "Content-Type: application/json" \
            -d "$body" \
            "$FORGEJO_API_BASE/repos/$owner/$repo_name/issues/$parent_number/dependencies" >/dev/null 2>&1
        set linked true
    end
    echo "$linked"
end
# ── Unsupported project-board operations ──────────────────────────────────────

function _backend_forgejo_list_projects
    _backend_forgejo_no_projects list-projects
end

function _backend_forgejo_view_project
    _backend_forgejo_no_projects view-project
end

function _backend_forgejo_create_project
    _backend_forgejo_no_projects create-project
end

function _backend_forgejo_list_fields
    _backend_forgejo_no_projects list-fields
end

function _backend_forgejo_create_field
    _backend_forgejo_no_projects create-field
end

function _backend_forgejo_add_item
    _backend_forgejo_no_projects add-item
end

function _backend_forgejo_add_item_by_id
    _backend_forgejo_no_projects add-item-by-id
end

function _backend_forgejo_remove_item
    _backend_forgejo_no_projects remove-item
end

function _backend_forgejo_update_select
    _backend_forgejo_no_projects update-select
end

function _backend_forgejo_update_text
    _backend_forgejo_no_projects update-text
end

function _backend_forgejo_update_number
    _backend_forgejo_no_projects update-number
end

function _backend_forgejo_update_date
    _backend_forgejo_no_projects update-date
end

function _backend_forgejo_get_project_id
    _backend_forgejo_no_projects get-project-id
end

function _backend_forgejo_add_to_board
    _backend_forgejo_no_projects add-to-board
end

function _backend_forgejo_set_field
    _backend_forgejo_no_projects set-field
end
# ── Implementable operations ──────────────────────────────────────────────────

function _backend_forgejo_list_items
    # Args: <repo> [--query <text>] [--first <n>] [--all] [--after <page>] [owner]
    set -l repo_arg ""
    set -l query_filter ""
    set -l first 50
    set -l fetch_all false
    set -l after_page ""
    set -l owner_override ""
    set -l i 1
    while test $i -le (count $argv)
        switch $argv[$i]
            case --query
                set i (math $i + 1)
                set query_filter "$argv[$i]"
            case --first
                set i (math $i + 1)
                set first "$argv[$i]"
            case --all
                set fetch_all true
            case --after
                set i (math $i + 1)
                set after_page "$argv[$i]"
            case '*'
                if test -z "$repo_arg"
                    set repo_arg "$argv[$i]"
                else
                    set owner_override "$argv[$i]"
                end
        end
        set i (math $i + 1)
    end

    test -z "$repo_arg"; and die "Usage: list-items <repo> [--query <text>] [--first <n>] [--all] [--after <page>] [owner]"

    if test -n "$after_page" -a "$after_page" -lt 1 2>/dev/null
        die "Invalid --after page: $after_page (must be a positive integer)"
    end

    set -l repo (_backend_forgejo_normalize_repo_with_owner "$repo_arg" "$owner_override")
    set -l parts (string split '/' "$repo")
    set -l owner "$parts[1]"
    set -l repo_name "$parts[2]"

    set -l all_items '[]'
    set -l page 1
    if test -n "$after_page"
        set page "$after_page"
    end
    set -l has_next true
    set -l meta_total 0
    set -l meta_has_more false
    set -l meta_cursor ""
    set -l header_file (mktemp)

    while test "$has_next" = true
        set -l curl_args -G --data-urlencode "state=all" --data-urlencode "limit=$first" --data-urlencode "page=$page"
        if test -n "$query_filter"
            set -a curl_args --data-urlencode "q=$query_filter"
        end

        set -l response (curl -sS -D "$header_file" -H "Authorization: token $FORGEJO_TOKEN" \
            -H "Accept: application/json" \
            "$FORGEJO_API_BASE/repos/$owner/$repo_name/issues" $curl_args)

        if test $status -ne 0
            rm "$header_file"
            die "Failed to list items for $repo."
        end

        set -l page_items (echo "$response" | jq '[.[] | {id, number, title, state, url: .html_url, fields: {}}]' 2>/dev/null)
        if test -z "$page_items"
            set page_items '[]'
        end

        set all_items (echo "$all_items" | jq --argjson items "$page_items" '. + $items')

        set -l total_from_header (_backend_forgejo_total_from_headers "$header_file")
        if test -n "$total_from_header"
            set meta_total "$total_from_header"
        else
            set meta_total (echo "$all_items" | jq 'length')
        end

        if _backend_forgejo_has_next_page "$header_file"
            set meta_has_more true
            set meta_cursor (math $page + 1)
            if test "$fetch_all" = true
                set page (math $page + 1)
            else
                set has_next false
            end
        else
            set meta_has_more false
            set meta_cursor ""
            set has_next false
        end
    end

    rm "$header_file"

    if test "$JSON_MODE" = true
        echo '{}' | jq --argjson items "$all_items" \
            --argjson total "$meta_total" \
            --arg cursor "$meta_cursor" \
            --arg has_more "$meta_has_more" \
            --arg query "$query_filter" \
            '{total: $total, has_more: ($has_more == "true"), end_cursor: $cursor, query: (if $query == "" then null else $query end), items: $items}'
    else
        echo "$all_items" | jq -r '.[] | "#\(.number)\t\(.title)\t\(.state)\t\(.url)\t-"' | column -t -s\t
    end
end

function _backend_forgejo_count_items
    # Args: <repo> [query] [--owner <owner>]
    set -l repo_arg ""
    set -l query_filter ""
    set -l owner_override ""

    set -l i 1
    while test $i -le (count $argv)
        switch $argv[$i]
            case --owner
                set i (math $i + 1)
                set owner_override "$argv[$i]"
            case '*'
                if test -z "$repo_arg"
                    set repo_arg "$argv[$i]"
                else if test -z "$query_filter"
                    set query_filter "$argv[$i]"
                end
        end
        set i (math $i + 1)
    end

    test -z "$repo_arg"; and die "Usage: count-items <repo> [query] [--owner <owner>]"

    set -l repo (_backend_forgejo_normalize_repo_with_owner "$repo_arg" "$owner_override")
    set -l parts (string split '/' "$repo")
    set -l owner "$parts[1]"
    set -l repo_name "$parts[2]"

    set -l header_file (mktemp)
    set -l curl_args -G --data-urlencode "state=all" --data-urlencode "limit=1" --data-urlencode "page=1"
    if test -n "$query_filter"
        set -a curl_args --data-urlencode "q=$query_filter"
    end

    curl -sS -D "$header_file" -H "Authorization: token $FORGEJO_TOKEN" \
        -H "Accept: application/json" \
        "$FORGEJO_API_BASE/repos/$owner/$repo_name/issues" $curl_args >/dev/null

    if test $status -ne 0
        rm "$header_file"
        die "Failed to count items for $repo."
    end

    set -l total (_backend_forgejo_total_from_headers "$header_file")
    if test -z "$total"
        # Fallback: fetch one page and count (best effort if header missing)
        set -l response (curl -sS -G -H "Authorization: token $FORGEJO_TOKEN" \
            -H "Accept: application/json" \
            "$FORGEJO_API_BASE/repos/$owner/$repo_name/issues" \
            --data-urlencode "state=all" --data-urlencode "limit=100" --data-urlencode "page=1")
        set total (echo "$response" | jq 'length')
    end

    rm "$header_file"

    if test "$JSON_MODE" = true
        echo '{}' | jq --argjson total "$total" \
            --arg repo "$repo" \
            --arg query "$query_filter" \
            '{repo: $repo, query: (if $query == "" then null else $query end), total: $total}'
    else
        echo "$total"
    end
end

function _backend_forgejo_get_content_id
    set -l repo_arg "$argv[1]"
    set -l number "$argv[2]"

    test -z "$repo_arg"; and die "Usage: get-content-id <repo> <number>"
    test -z "$number"; and die "Usage: get-content-id <repo> <number>"

    set -l repo (normalize_repo "$repo_arg")
    set -l parts (string split '/' "$repo")

    set -l result (_backend_forgejo_api_get "/repos/$parts[1]/$parts[2]/issues/$number")
    set -l content_id (echo "$result" | jq -r '.id // empty')

    test -z "$content_id" -o "$content_id" = null; and die "Issue #$number not found in $repo."

    if test "$JSON_MODE" = true
        echo '{}' | jq --argjson cid "$content_id" '{content_id: $cid}'
    else
        echo "$content_id"
    end
end

function _backend_forgejo_report
    # Args: <repo> [owner]
    set -l repo_arg "$argv[1]"
    set -l owner_override "$argv[2]"

    test -z "$repo_arg"; and die "Usage: report <repo> [owner]"

    set -l repo (_backend_forgejo_normalize_repo_with_owner "$repo_arg" "$owner_override")
    set -l parts (string split '/' "$repo")
    set -l owner "$parts[1]"
    set -l repo_name "$parts[2]"

    set -l header_file (mktemp)

    # Fetch first page of all issues (with headers for total)
    set -l all_response (curl -sS -D "$header_file" -G -H "Authorization: token $FORGEJO_TOKEN" \
        -H "Accept: application/json" \
        "$FORGEJO_API_BASE/repos/$owner/$repo_name/issues" \
        --data-urlencode "state=all" --data-urlencode "limit=50" --data-urlencode "page=1")

    if test $status -ne 0
        rm "$header_file"
        die "Failed to fetch issues for $repo."
    end

    set -l total (_backend_forgejo_total_from_headers "$header_file")
    if test -z "$total"
        set total (echo "$all_response" | jq 'length')
    end
    rm "$header_file"

    # Count open/closed via separate small calls (header-based)
    set -l open_count 0
    set -l closed_count 0

    set -l hdr_open (mktemp)
    curl -sS -D "$hdr_open" -G -H "Authorization: token $FORGEJO_TOKEN" \
        -H "Accept: application/json" \
        "$FORGEJO_API_BASE/repos/$owner/$repo_name/issues" \
        --data-urlencode "state=open" --data-urlencode "limit=1" --data-urlencode "page=1" >/dev/null
    set open_count (_backend_forgejo_total_from_headers "$hdr_open")
    rm "$hdr_open"

    set -l hdr_closed (mktemp)
    curl -sS -D "$hdr_closed" -G -H "Authorization: token $FORGEJO_TOKEN" \
        -H "Accept: application/json" \
        "$FORGEJO_API_BASE/repos/$owner/$repo_name/issues" \
        --data-urlencode "state=closed" --data-urlencode "limit=1" --data-urlencode "page=1" >/dev/null
    set closed_count (_backend_forgejo_total_from_headers "$hdr_closed")
    rm "$hdr_closed"

    if test -z "$open_count"
        set open_count 0
    end
    if test -z "$closed_count"
        set closed_count 0
    end

    # Fetch milestones
    set -l milestones (_backend_forgejo_api_get "/repos/$owner/$repo_name/milestones" \
        --data-urlencode "state=all" --data-urlencode "limit=100")

    set -l project_data (echo '{}' | jq \
        --arg repo "$repo" \
        --argjson total "$total" \
        --argjson open "$open_count" \
        --argjson closed "$closed_count" \
        --argjson milestones "$milestones" \
        --argjson items "$all_response" \
        '{
            repo: $repo,
            total: $total,
            open: $open,
            closed: $closed,
            by_state: [
                {state: "open", count: $open},
                {state: "closed", count: $closed}
            ],
            milestones: [
                $milestones[] | {
                    title,
                    state,
                    open_issues,
                    closed_issues,
                    total_issues: (.open_issues + .closed_issues)
                }
            ],
            items: [
                $items[] | {
                    id,
                    number,
                    title,
                    state,
                    url: .html_url
                }
            ]
        }')

    if test "$JSON_MODE" = true
        echo "$project_data"
    else
        set -l title (echo "$project_data" | jq -r '.repo')
        set -l total_h (echo "$project_data" | jq '.total')
        set -l open_h (echo "$project_data" | jq '.open')
        set -l closed_h (echo "$project_data" | jq '.closed')

        echo ""
        echo "========================================="
        echo "Repository: $title"
        echo "========================================="
        echo "Total issues: $total_h"
        echo ""
        echo "By State:"
        echo "  open: $open_h"
        echo "  closed: $closed_h"
        echo ""
        echo "Completion: $closed_h/$total_h"
        echo ""

        set -l ms_count (echo "$project_data" | jq '.milestones | length')
        if test "$ms_count" -gt 0
            echo "Milestones:"
            echo "$project_data" | jq -r '.milestones[] | "  \(.title): \(.open_issues) open / \(.closed_issues) closed"'
            echo ""
        end

        echo "Items:"
        echo "$project_data" | jq -r '.items[] | "  #\(.number) \(.title) [\(.state)] \(.url)"'
    end
end

function _backend_forgejo_create_story
    set -l result (_backend_forgejo_create_labeled_issue $argv[1] $argv[2] story 5 $argv[3..])
    set -l issue_number (echo "$result" | jq -r '.number')
    log_success "Created story #$issue_number: $argv[2]"
    echo "$result" | jq '{number, id, node_id: (.id | tostring), url: .html_url}'
end

function _backend_forgejo_create_task
    set -l repo $argv[1]
    set -l title $argv[2]
    set -l parent_number $argv[3]

    set -l result (_backend_forgejo_create_labeled_issue "$repo" "$title" task 5 $argv[4..])
    set -l task_info (echo "$result" | jq '{number, id, url: .html_url}')
    set -l task_number (echo "$task_info" | jq -r '.number')

    set -l linked (_backend_forgejo_link_dependency "$repo" "$parent_number" "$task_number")

    if test "$linked" != true
        log_warn "Created task but failed to link as dependency (GitHub-style sub-issues are not native to Forgejo)"
    end

    set -l issue_number (echo "$task_info" | jq -r '.number')
    log_success "Created task #$issue_number: $title"

    echo "$task_info" | jq --argjson linked "$linked" '{number, id, node_id: (.id | tostring), url, linked: $linked}'
end
