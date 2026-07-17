# @fish-lsp-disable 4004
#
# _backend_github.fish — GitHub implementation of project-manager operations
#
# Sourced by project-manager.fish; never run directly. The _op_* dispatchers
# in the main script route here when PROJECT_MANAGER_BACKEND=github. Each
# _backend_github_<op> function owns the full operation: API calls (GraphQL/REST
# via $GH_CLI), response parsing, and JSON_MODE/human output formatting. Any
# other backend must emit the same output shapes and error semantics per op.
# Shared helpers (resolve_owner, normalize_repo) live in the main script;
# log_*/die come from tools/common/log.fish.

# ── GitHub-specific helpers ───────────────────────────────────────────────────

function resolve_owner_type
    set -l owner "$argv[1]"
    if test -n "$_OWNER_TYPE"
        echo "$_OWNER_TYPE"
        return
    end
    set -g _OWNER_TYPE organization
    if $GH_CLI api graphql -f query='query($login: String!) { user(login: $login) { id } }' \
            -f login="$owner" --jq '.data.user.id' >/dev/null 2>&1
        set -g _OWNER_TYPE user
    end
    echo "$_OWNER_TYPE"
end

# Ensure a label exists in the repo, creating it if needed.
function _backend_github_ensure_label
    set -l repo $argv[1]
    set -l label $argv[2]

    set -l create_out ($GH_CLI label create "$label" --repo "$repo" 2>&1)
    if test $status -eq 0
        log_info "Created label '$label' in $repo"
        return 0
    end

    if test -n "$create_out"
        and string match -q '*already exists*' -- $create_out
        return 0
    end
    set -l exists ($GH_CLI label list --repo "$repo" --json name \
        --jq ".[] | select(.name == \"$label\") | .name" 2>/dev/null)
    if test "$exists" = "$label"
        return 0
    end

    die "Failed to create label '$label' in $repo: $create_out"
end
# ── Project operations ────────────────────────────────────────────────────────

function _backend_github_list_projects
    set -l owner (resolve_owner "$argv[1]")
    set -l owner_type (resolve_owner_type "$owner")

    set -l data ($GH_CLI api graphql -f query="
query(\$owner: String!) {
  $owner_type(login: \$owner) {
    projectsV2(first: 20) {
      nodes { number title url }
    }
  }
}" -f owner="$owner" 2>/dev/null)
    test -z "$data"; and die "Failed to list projects for $owner."

    if test "$JSON_MODE" = true
        echo "$data" | jq '{projects: [.data | .user // .organization | .projectsV2.nodes[] | {number, title, url}]}'
    else
        echo "$data" | jq -r '.data | .user // .organization | .projectsV2.nodes[] | "#\(.number)\t\(.title)\t\(.url)"' | column -t -s\t
    end
end

function _backend_github_view_project
    set -l number "$argv[1]"
    set -l owner (resolve_owner "$argv[2]")
    set -l owner_type (resolve_owner_type "$owner")

    set -l data ($GH_CLI api graphql -f query="
query(\$owner: String!, \$number: Int!) {
  $owner_type(login: \$owner) {
    projectV2(number: \$number) {
      number: number
      title
      url
      items(first: 1) { totalCount }
    }
  }
}" -f owner="$owner" -F number="$number" 2>/dev/null)

    if not echo "$data" | jq -e '.data | (.user // .organization).projectV2' >/dev/null 2>&1
        die "Project #$number not found for $owner."
    end

    if test "$JSON_MODE" = true
        echo "$data" | jq '{number: (.data | .user // .organization | .projectV2.number),
                           title: (.data | .user // .organization | .projectV2.title),
                           url: (.data | .user // .organization | .projectV2.url),
                           items_count: (.data | .user // .organization | .projectV2.items.totalCount)}'
    else
        set -l project (echo "$data" | jq '.data | .user // .organization | .projectV2')
        echo ""
        echo "Project: #(echo "$project" | jq -r '.number') (echo "$project" | jq -r '.title')"
        echo "URL: (echo "$project" | jq -r '.url')"
        echo "Items: (echo "$project" | jq '.items.totalCount')"
    end
end

function _backend_github_create_project
    set -l title "$argv[1]"
    set -l owner (resolve_owner "$argv[2]")
    set -l owner_type (resolve_owner_type "$owner")

    # Determine the correct owner ID field for the mutation
    set -l owner_id ($GH_CLI api graphql -f query="
query(\$login: String!) {
  $owner_type(login: \$login) { id }
}" -f login="$owner" --jq ".data.$owner_type.id" 2>/dev/null)
    test -z "$owner_id" -o "$owner_id" = null; and die "Failed to resolve owner ID for $owner."

    set -l data ($GH_CLI api graphql -f query="
mutation(\$ownerId: ID!, \$title: String!) {
  createProjectV2(input: {ownerId: \$ownerId, title: \$title}) {
    projectV2 { id number:title title url }
  }
}" -f ownerId="$owner_id" -f title="$title" 2>/dev/null)
    test -z "$data"; and die "Failed to create project '$title'."

    if test "$JSON_MODE" = true
        echo "$data" | jq '{id: .data.createProjectV2.projectV2.id, title: .data.createProjectV2.projectV2.title, url: .data.createProjectV2.projectV2.url}'
    else
        echo "$data" | jq '.data.createProjectV2.projectV2 | "Created: \(.title) — \(.url)"'
    end
    log_success "Created project: $title"
end

# ── Field operations ──────────────────────────────────────────────────────────

function _backend_github_list_fields
    set -l number "$argv[1]"
    set -l owner (resolve_owner "$argv[2]")
    set -l owner_type (resolve_owner_type "$owner")

    set -l data ($GH_CLI api graphql -f query="
query(\$owner: String!, \$number: Int!) {
  $owner_type(login: \$owner) {
    projectV2(number: \$number) {
      fields(first: 20) {
        nodes {
          ... on ProjectV2Field { id name dataType }
          ... on ProjectV2SingleSelectField { id name options { id name } }
        }
      }
    }
  }
}" -f owner="$owner" -F number="$number" 2>/dev/null)

    if not echo "$data" | jq -e '.data | (.user // .organization).projectV2' >/dev/null 2>&1
        die "Project #$number not found for $owner."
    end

    set -l fields (echo "$data" | jq '[.data | .user // .organization | .projectV2.fields.nodes[] |
        {id, name, type: (.dataType // "SINGLE_SELECT"), options: (.options // [])}]')

    if test "$JSON_MODE" = true
        echo "$fields" | jq '{fields: .}'
    else
        echo "$fields" | jq -r '.[] | "\(.id)\t\(.name)\t\(.type)\t\([.options[] | .name] | join(","))"' \
            | column -t -s\t
    end
end

function _backend_github_create_field
    set -l number "$argv[1]"
    set -l name "$argv[2]"
    set -l data_type "$argv[3]"
    set -l owner (resolve_owner "$argv[4]")

    set -l project_id (_backend_github_get_project_id "$number" "$owner" | jq -r '.project_id')
    test -z "$project_id" -o "$project_id" = null; and die "Project #$number not found."

    set -l data
    switch $data_type
        case SINGLE_SELECT
            # GitHub GraphQL API doesn't support passing options on field creation directly.
            # Create the field without options; user can add options via GitHub UI.
            set data ($GH_CLI api graphql -f query="
mutation(\$projectId: ID!, \$name: String!) {
  createProjectV2Field(input: {projectId: \$projectId, name: \$name, dataType: SINGLE_SELECT}) {
    projectV2Field { id name }
  }
}" -f projectId="$project_id" -f name="$name" 2>/dev/null)
        case '*'
            set data ($GH_CLI api graphql -f query="
mutation(\$projectId: ID!, \$name: String!, \$dataType: ProjectV2CustomFieldType!) {
  createProjectV2Field(input: {projectId: \$projectId, name: \$name, dataType: \$dataType}) {
    projectV2Field { id name }
  }
}" -f projectId="$project_id" -f name="$name" -f dataType="$data_type" 2>/dev/null)
    end

    test -z "$data"; and die "Failed to create field '$name'."
    echo "$data" | jq '{id: .data.createProjectV2Field.projectV2Field.id, name: .data.createProjectV2Field.projectV2Field.name}'
    test "$JSON_MODE" = true; or log_success "Created field: $name ($data_type)"
end
# ── Item operations ───────────────────────────────────────────────────────────

function _backend_github_list_items
    # Args: <number> [--query <text>] [--first <n>] [--all] [--after <cursor>] [owner]
    set -l number ""
    set -l query_filter ""
    set -l first 100
    set -l fetch_all false
    set -l after_cursor ""
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
                set after_cursor "$argv[$i]"
            case '*'
                if test -z "$number"
                    set number "$argv[$i]"
                else
                    set owner_override "$argv[$i]"
                end
        end
        set i (math $i + 1)
    end

    test -z "$number"; and die "Usage: list-items <number> [--query <text>] [--first <n>] [--all] [--after <cursor>] [owner]"

    set -l owner (resolve_owner "$owner_override")
    set -l owner_type (resolve_owner_type "$owner")

    set -l all_items '[]'
    set -l cursor "$after_cursor"
    set -l has_next true
    set -l page 0

    while test "$has_next" = true
        set page (math $page + 1)

        # Build the items() call with optional params
        set -l items_args "first: $first"
        if test -n "$query_filter"
            set items_args "$items_args, query: \"\"\"$query_filter\"\"\""
        end
        if test -n "$cursor"
            set items_args "$items_args, after: \"$cursor\""
        end

        set data ($GH_CLI api graphql -f query="
query(\$owner: String!, \$number: Int!) {
  $owner_type(login: \$owner) {
    projectV2(number: \$number) {
      items($items_args) {
        totalCount
        pageInfo { hasNextPage endCursor }
        nodes {
          id
          content {
            ... on Issue { number title state url }
            ... on PullRequest { number title state url }
          }
          fieldValues(first: 10) {
            nodes {
              ... on ProjectV2ItemFieldSingleSelectValue {
                name
                field { ... on ProjectV2SingleSelectField { name } }
              }
            }
          }
        }
      }
    }
  }
}" -f owner="$owner" -F number="$number" 2>/dev/null)

        if not echo "$data" | jq -e '.data | (.user // .organization).projectV2' >/dev/null 2>&1
            die "Project #$number not found for $owner."
        end

        set -l page_items (echo "$data" | jq '[.data | .user // .organization | .projectV2.items.nodes[] |
            {
                id,
                number: (.content.number // "draft"),
                title: (.content.title // "Draft"),
                state: (.content.state // "-"),
                url: (.content.url // "-"),
                fields: [.fieldValues.nodes[] | select(.field) | {(.field.name): .name}] | add // {}
            }
        ]' 2>/dev/null)

        if test -z "$page_items"
            set page_items '[]'
        end

        set -l total_count (echo "$data" | jq '.data | (.user // .organization).projectV2.items.totalCount // 0')
        set -l next_page (echo "$data" | jq -r '.data | (.user // .organization).projectV2.items.pageInfo.hasNextPage // false')
        set -l next_cursor (echo "$data" | jq -r '.data | (.user // .organization).projectV2.items.pageInfo.endCursor // ""')

        # Accumulate items
        set all_items (echo "$all_items" | jq --argjson items "$page_items" '. + $items')

        log_info "Fetched page $page ($total_count total items)"

        if test "$fetch_all" = true -a "$next_page" = true
            set cursor "$next_cursor"
        else
            set has_next false
        end
    end

    # Get total_count from last response for metadata
    set -l meta_total (echo "$data" | jq '.data | (.user // .organization).projectV2.items.totalCount // 0')
    set -l meta_cursor (echo "$data" | jq -r '.data | (.user // .organization).projectV2.items.pageInfo.endCursor // ""')
    set -l meta_has_more (echo "$data" | jq -r '.data | (.user // .organization).projectV2.items.pageInfo.hasNextPage // false')

    if test "$JSON_MODE" = true
        echo '{}' | jq --argjson items "$all_items" \
            --argjson total "$meta_total" \
            --arg cursor "$meta_cursor" \
            --arg has_more "$meta_has_more" \
            --arg query "$query_filter" \
            '{total: $total, has_more: ($has_more == "true"), end_cursor: $cursor, query: (if $query == "" then null else $query end), items: $items}'
    else
        echo "$all_items" | jq -r '.[] | "#\(.number)\t\(.title)\t\(.state)\t\(.url)\t\([.fields | to_entries[] | "\(.key)=\(.value)"] | join(" "))"' | column -t -s\t
    end
end

function _backend_github_add_item
    set -l number "$argv[1]"
    set -l url "$argv[2]"
    set -l owner (resolve_owner "$argv[3]")

    # Extract repo and issue number from URL
    set -l parts (string replace -r 'https://github.com/([^/]+)/([^/]+)/issues/(\d+)' '$1/$2 $3' "$url" | string split ' ')
    test (count $parts) -lt 2; and die "Invalid issue URL: $url"
    set -l repo $parts[1]
    set -l issue_num $parts[2]

    set -l content_id ($GH_CLI api "repos/$repo/issues/$issue_num" --jq '.node_id' 2>/dev/null)
    test -z "$content_id" -o "$content_id" = null; and die "Issue not found: $url"

    set -l project_id (_backend_github_get_project_id "$number" "$owner" | jq -r '.project_id')
    test -z "$project_id" -o "$project_id" = null; and die "Project #$number not found."

    set -l item_id ($GH_CLI api graphql -f query='
mutation($projectId: ID!, $contentId: ID!) {
  addProjectV2ItemById(input: {projectId: $projectId, contentId: $contentId}) {
    item { id }
  }
}' -f projectId="$project_id" -f contentId="$content_id" --jq '.data.addProjectV2ItemById.item.id' 2>/dev/null)
    test -z "$item_id" -o "$item_id" = null; and die "Failed to add item to project #$number."

    if test "$JSON_MODE" = true
        echo "{}" | jq --arg id "$item_id" '{item_id: $id, status: "added"}'
    else
        echo "$item_id"
        log_success "Added item to project #$number"
    end
end

function _backend_github_add_item_by_id
    set -l project_id "$argv[1]"
    set -l content_id "$argv[2]"

    set -l item_id ($GH_CLI api graphql -f query='
mutation($projectId: ID!, $contentId: ID!) {
  addProjectV2ItemById(input: {projectId: $projectId, contentId: $contentId}) {
    item { id }
  }
}' -f projectId="$project_id" -f contentId="$content_id" --jq '.data.addProjectV2ItemById.item.id' 2>/dev/null)
    test -z "$item_id" -o "$item_id" = null; and die "Failed to add item to project."

    if test "$JSON_MODE" = true
        echo "{}" | jq --arg id "$item_id" '{item_id: $id}'
    else
        echo "$item_id"
        log_success "Added item to project"
    end
end

function _backend_github_remove_item
    set -l project_id "$argv[1]"
    set -l item_id "$argv[2]"

    $GH_CLI api graphql -f query='
mutation($projectId: ID!, $itemId: ID!) {
  deleteProjectV2Item(input: {projectId: $projectId, itemId: $itemId}) {
    deletedItemId
  }
}' -f projectId="$project_id" -f itemId="$item_id" >/dev/null 2>&1
    or die "Failed to remove item from project."

    if test "$JSON_MODE" = true
        echo '{}' | jq --arg pid "$project_id" --arg iid "$item_id" \
            '{project_id: $pid, item_id: $iid, status: "removed"}'
    else
        log_success "Removed item from project"
    end
end

# ── Field update operations ──────────────────────────────────────────────────

function _backend_github_update_select
    set -l project_id "$argv[1]"
    set -l item_id "$argv[2]"
    set -l field_id "$argv[3]"
    set -l option_id "$argv[4]"

    $GH_CLI api graphql -f query='
mutation($projectId: ID!, $itemId: ID!, $fieldId: ID!, $optionId: String!) {
  updateProjectV2ItemFieldValue(input: {
    projectId: $projectId, itemId: $itemId, fieldId: $fieldId,
    value: { singleSelectOptionId: $optionId }
  }) { projectV2Item { id } }
}' -f projectId="$project_id" -f itemId="$item_id" -f fieldId="$field_id" -f optionId="$option_id" >/dev/null 2>&1
    or die "Failed to update select field."

    if test "$JSON_MODE" = true
        echo "{}" | jq --arg pid "$project_id" --arg iid "$item_id" \
            --arg fid "$field_id" --arg oid "$option_id" \
            '{project_id: $pid, item_id: $iid, field_id: $fid, option_id: $oid, status: "updated"}'
    else
        log_success "Updated select field"
    end
end

function _backend_github_update_text
    set -l project_id "$argv[1]"
    set -l item_id "$argv[2]"
    set -l field_id "$argv[3]"
    set -l text "$argv[4]"

    $GH_CLI api graphql -f query='
mutation($projectId: ID!, $itemId: ID!, $fieldId: ID!, $text: String!) {
  updateProjectV2ItemFieldValue(input: {
    projectId: $projectId, itemId: $itemId, fieldId: $fieldId,
    value: { text: $text }
  }) { projectV2Item { id } }
}' -f projectId="$project_id" -f itemId="$item_id" -f fieldId="$field_id" -f text="$text" >/dev/null 2>&1
    or die "Failed to update text field."

    if test "$JSON_MODE" = true
        echo "{}" | jq --arg pid "$project_id" --arg iid "$item_id" \
            --arg fid "$field_id" \
            '{project_id: $pid, item_id: $iid, field_id: $fid, status: "updated"}'
    else
        log_success "Updated text field"
    end
end

function _backend_github_update_number
    set -l project_id "$argv[1]"
    set -l item_id "$argv[2]"
    set -l field_id "$argv[3]"
    set -l number "$argv[4]"

    $GH_CLI api graphql -f query='
mutation($projectId: ID!, $itemId: ID!, $fieldId: ID!, $number: Float!) {
  updateProjectV2ItemFieldValue(input: {
    projectId: $projectId, itemId: $itemId, fieldId: $fieldId,
    value: { number: $number }
  }) { projectV2Item { id } }
}' -f projectId="$project_id" -f itemId="$item_id" -f fieldId="$field_id" -F number="$number" >/dev/null 2>&1
    or die "Failed to update number field."

    if test "$JSON_MODE" = true
        echo "{}" | jq --arg pid "$project_id" --arg iid "$item_id" \
            --arg fid "$field_id" --argjson val "$number" \
            '{project_id: $pid, item_id: $iid, field_id: $fid, value: $val, status: "updated"}'
    else
        log_success "Updated number field"
    end
end

function _backend_github_update_date
    set -l project_id "$argv[1]"
    set -l item_id "$argv[2]"
    set -l field_id "$argv[3]"
    set -l date_val "$argv[4]"

    $GH_CLI api graphql -f query='
mutation($projectId: ID!, $itemId: ID!, $fieldId: ID!, $date: Date!) {
  updateProjectV2ItemFieldValue(input: {
    projectId: $projectId, itemId: $itemId, fieldId: $fieldId,
    value: { date: $date }
  }) { projectV2Item { id } }
}' -f projectId="$project_id" -f itemId="$item_id" -f fieldId="$field_id" -f date="$date_val" >/dev/null 2>&1
    or die "Failed to update date field."

    if test "$JSON_MODE" = true
        echo "{}" | jq --arg pid "$project_id" --arg iid "$item_id" \
            --arg fid "$field_id" --arg val "$date_val" \
            '{project_id: $pid, item_id: $iid, field_id: $fid, value: $val, status: "updated"}'
    else
        log_success "Updated date field"
    end
end
# ── ID lookups ────────────────────────────────────────────────────────────────

function _backend_github_get_project_id
    set -l number "$argv[1]"
    set -l owner (resolve_owner "$argv[2]")
    set -l owner_type (resolve_owner_type "$owner")

    set -l data ($GH_CLI api graphql -f query="
query(\$owner: String!, \$number: Int!) {
  $owner_type(login: \$owner) { projectV2(number: \$number) { id title } }
}" -f owner="$owner" -F number="$number" 2>/dev/null)

    if not echo "$data" | jq -e ".data.$owner_type.projectV2" >/dev/null 2>&1
        die "Project #$number not found for $owner."
    end

    set -l project_id (echo "$data" | jq -r ".data.$owner_type.projectV2.id")

    if test "$JSON_MODE" = true
        echo "{}" | jq --arg pid "$project_id" '{project_id: $pid}'
    else
        echo "$project_id"
    end
end

function _backend_github_get_content_id
    set -l repo "$argv[1]"
    set -l number "$argv[2]"

    set -l content_id ($GH_CLI api "repos/$repo/issues/$number" --jq '.node_id' 2>/dev/null)
    test -z "$content_id" -o "$content_id" = null; and die "Issue #$number not found in $repo."

    if test "$JSON_MODE" = true
        echo "{}" | jq --arg cid "$content_id" '{content_id: $cid}'
    else
        echo "$content_id"
    end
end
# ── Count items ──────────────────────────────────────────────────────────────

function _backend_github_count_items
    set -l number "$argv[1]"
    set -l query_filter ""
    set -l owner_override ""

    # Parse: number [query] [--owner <owner>]
    set -l i 2
    while test $i -le (count $argv)
        switch $argv[$i]
            case --owner
                set i (math $i + 1)
                set owner_override "$argv[$i]"
            case '*'
                # First non-flag arg is the query filter
                if test -z "$query_filter"
                    set query_filter "$argv[$i]"
                end
        end
        set i (math $i + 1)
    end

    set -l owner (resolve_owner "$owner_override")
    set -l owner_type (resolve_owner_type "$owner")

    set -l query_args ""
    if test -n "$query_filter"
        set query_args ", query: \"\"\"$query_filter\"\"\""
    end

    set -l data ($GH_CLI api graphql -f query="
query(\$owner: String!, \$number: Int!) {
  $owner_type(login: \$owner) {
    projectV2(number: \$number) {
      items(first: 1$query_args) { totalCount }
    }
  }
}" -f owner="$owner" -F number="$number" 2>/dev/null)

    if not echo "$data" | jq -e '.data | (.user // .organization).projectV2' >/dev/null 2>&1
        die "Project #$number not found for $owner."
    end

    set -l total (echo "$data" | jq '.data | (.user // .organization).projectV2.items.totalCount')

    if test "$JSON_MODE" = true
        echo '{}' | jq --argjson total "$total" \
            --arg number "$number" \
            --arg owner "$owner" \
            '{project_number: ($number | tonumber), owner: $owner, total: $total}'
    else
        echo "$total"
    end
end

# ── Report ────────────────────────────────────────────────────────────────────

function _backend_github_report
    set -l number "$argv[1]"
    set -l owner (resolve_owner "$argv[2]")
    set -l owner_type (resolve_owner_type "$owner")

    set -l result ($GH_CLI api graphql -f query="
query(\$owner: String!, \$number: Int!) {
  $owner_type(login: \$owner) {
    projectV2(number: \$number) {
      title
      items(first: 100) {
        nodes {
          id
          content {
            ... on Issue { number title state url }
            ... on PullRequest { number title state url }
          }
          fieldValues(first: 10) {
            nodes {
              ... on ProjectV2ItemFieldSingleSelectValue {
                name
                field { ... on ProjectV2SingleSelectField { name } }
              }
            }
          }
        }
      }
    }
  }
}" -f owner="$owner" -F number="$number" 2>/dev/null)

    if not echo "$result" | jq -e '.data | (.user // .organization).projectV2' >/dev/null 2>&1
        die "Project #$number not found for $owner."
    end

    set -l project_data (echo "$result" | jq ".data.$owner_type.projectV2")

    if test "$JSON_MODE" = true
        echo "$project_data" | jq '{
            title,
            total: (.items.nodes | length),
            by_status: [
                .items.nodes |
                map({status: (.fieldValues.nodes[] | select(.field) | select(.field.name == "Status") | .name) // "No Status"}) |
                group_by(.status) |
                map({status: .[0].status, count: length}) |
                sort_by(-.count)
            ][],
            items: [.items.nodes[] | {
                id,
                number: (.content.number // "draft"),
                title: (.content.title // "Draft"),
                state: (.content.state // "-"),
                url: (.content.url // "-"),
                fields: [.fieldValues.nodes[] | select(.field) | {(.field.name): .name}] | add // {}
            }]
        }'
    else
        set -l title (echo "$project_data" | jq -r '.title')
        set -l total (echo "$project_data" | jq '.items.nodes | length')

        echo ""
        echo "========================================="
        echo "Project: $title"
        echo "========================================="
        echo "Total items: $total"
        echo ""

        echo "By Status:"
        echo "$project_data" | jq -r '
            [.items.nodes[] |
                {status: (.fieldValues.nodes[] | select(.field) | select(.field.name == "Status") | .name) // "No Status"}
            ] | group_by(.status) | map({status: .[0].status, count: length}) | sort_by(-.count) | .[] |
            "  \(.status): \(.count)"
        '
        echo ""

        set -l done_count (echo "$project_data" | jq '[.items.nodes[] | select(.fieldValues.nodes[]? | select(.field.name == "Status" and .name == "Done"))] | length')
        echo "Completion: $done_count/$total"
        echo ""

        echo "Items:"
        echo "$project_data" | jq -r '
            .items.nodes[] |
            "  #\(.content.number // "draft") \(.content.title // "Draft") [\(.content.state // "-")] \(.url // "")"
        '
    end
end
# ── Story & task creation ─────────────────────────────────────────────────────

function _backend_github_create_labeled_issue
    set -l repo (normalize_repo $argv[1])
    set -l title $argv[2]
    set -l default_label $argv[3]
    set -l flag_start $argv[4]

    set -l label $default_label
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

    # Write stdin to a temp file to preserve newlines.
    # Using `set -l body (cat)` splits on newlines in fish, destroying formatting.
    set -l body_file (mktemp)
    cat >$body_file
    if not test -s $body_file
        rm $body_file
        die "Body is empty. Pipe content to stdin."
    end

    _backend_github_ensure_label "$repo" "$label"

    set -l result
    if not set result ($GH_CLI issue create --repo "$repo" \
            --title "$title" \
            --body-file "$body_file" \
            --label "$label" 2>&1)
        rm $body_file
        die "Failed to create issue: $result"
    end
    rm $body_file

    # gh issue create outputs a URL. Fetch the issue data via API.
    set -l issue_url (echo "$result" | string match -r 'https://github.com/[^ ]+' 2>/dev/null; or echo "$result")
    set -l parts (string replace -r 'https://github.com/([^/]+)/([^/]+)/issues/(\d+)' '$1/$2 $3' "$issue_url" | string split ' ')
    test (count $parts) -lt 2; and die "Could not parse issue URL: $result"

    set -l issue_data ($GH_CLI api "repos/$parts[1]/issues/$parts[2]" --jq '{number, node_id, url: .html_url}' 2>/dev/null)
    test -z "$issue_data"; and die "Failed to fetch issue data after creation."

    echo "$issue_data"
end

function _backend_github_link_sub_issue
    set -l parent_node_id $argv[1]
    set -l child_node_id $argv[2]

    set -l linked false
    if $GH_CLI api graphql -f query='
        mutation($parentId: ID!, $childId: ID!) {
            addSubIssue(input: {issueId: $parentId, subIssueId: $childId}) {
                issue { id }
            }
        }' -f parentId="$parent_node_id" -f childId="$child_node_id" >/dev/null 2>&1
        set linked true
    end
    echo "$linked"
end

# Create a story issue. Forwards --label flags (if any) to _backend_github_create_labeled_issue via flag_start=5.
function _backend_github_create_story
    set -l result (_backend_github_create_labeled_issue $argv[1] $argv[2] story 5 $argv[3..])
    set -l issue_number (echo "$result" | jq -r '.number')
    log_success "Created story #$issue_number: $argv[2]"
    echo "$result" | jq '{number, node_id, url}'
end

# Create a task sub-issue linked to a parent. Forwards --label flags (if any) via flag_start=5.
function _backend_github_create_task
    set -l repo $argv[1]
    set -l title $argv[2]
    set -l parent_node_id $argv[3]
    set -l result (_backend_github_create_labeled_issue "$repo" "$title" task 5 $argv[4..])

    set -l task_info (echo "$result" | jq '{number, node_id, url}')
    set -l task_node_id (echo "$task_info" | jq -r '.node_id')

    set -l linked (_backend_github_link_sub_issue "$parent_node_id" "$task_node_id")

    if test "$linked" != true
        log_warn "Created task but failed to link as sub-issue"
    end

    set -l issue_number (echo "$task_info" | jq -r '.number')
    log_success "Created task #$issue_number: $title"

    echo "$task_info" | jq --argjson linked "$linked" '. + {linked: $linked}'
end
# ── Board operations (inlined — no longer spawns a separate script) ───────────

function _backend_github_add_to_board
    set -l project_number $argv[1]
    set -l node_ids $argv[2..]

    test (count $node_ids) -eq 0; and die "No node IDs provided"

    set -l owner (resolve_owner)

    # Call internal function directly instead of spawning a separate script
    set -l project_id (_backend_github_get_project_id "$project_number" "$owner" | jq -r '.project_id')
    test -z "$project_id" -o "$project_id" = null; and die "Failed to get project ID for #$project_number"

    set -l success_count 0
    set -l fail_count 0
    set -l item_ids

    for node_id in $node_ids
        set -l item_id_raw (_backend_github_add_item_by_id "$project_id" "$node_id")
        set -l item_id (echo "$item_id_raw" | jq -r '.item_id // empty')

        if test -n "$item_id" -a "$item_id" != null
            set -a item_ids "$item_id"
            set success_count (math $success_count + 1)
        else
            log_warn "Failed to add $node_id"
            set fail_count (math $fail_count + 1)
        end
    end

    log_success "Added $success_count items to project #$project_number"
    test $fail_count -gt 0; and log_warn "Failed to add $fail_count items"

    set -l ids_json
    if test (count $item_ids) -eq 0
        set ids_json '[]'
    else
        set ids_json (printf '%s\n' $item_ids | jq -R . | jq -s .)
    end

    echo '{}' | jq \
        --arg project_id "$project_id" \
        --argjson item_ids "$ids_json" \
        --argjson success_count "$success_count" \
        --argjson fail_count "$fail_count" \
        '{project_id: $project_id, item_ids: $item_ids, success_count: $success_count, fail_count: $fail_count}'
end

function _backend_github_set_field
    set -l project_id $argv[1]
    set -l item_id $argv[2]
    set -l field_name $argv[3]
    set -l option_name $argv[4]

    set -l field_info ($GH_CLI api graphql -f query='
query($projectId: ID!) {
  node(id: $projectId) {
    ... on ProjectV2 {
      fields(first: 20) {
        nodes {
          ... on ProjectV2SingleSelectField { id name options { id name } }
        }
      }
    }
  }
}' -f projectId="$project_id" 2>/dev/null)
    test -z "$field_info"; and die "Failed to get fields for project."

    set -l field_id (echo "$field_info" | jq -r --arg fname "$field_name" '
        [.data.node.fields.nodes[] | select(.name == $fname)][0].id
    ')

    test -z "$field_id" -o "$field_id" = null; and die "Field '$field_name' not found"

    set -l option_id (echo "$field_info" | jq -r --arg fname "$field_name" --arg oname "$option_name" '
        [.data.node.fields.nodes[] | select(.name == $fname)][0].options[] | select(.name == $oname) | .id
    ')

    test -z "$option_id" -o "$option_id" = null; and die "Option '$option_name' not found in field '$field_name'"

    # Perform the update (suppress inner output — we emit our own summary)
    _backend_github_update_select "$project_id" "$item_id" "$field_id" "$option_id" >/dev/null
    or die "Failed to update field '$field_name'."

    log_success "Set $field_name = $option_name"

    echo '{}' | jq \
        --arg project_id "$project_id" \
        --arg item_id "$item_id" \
        --arg field_name "$field_name" \
        --arg option_name "$option_name" \
        '{project_id: $project_id, item_id: $item_id, field_name: $field_name, option_name: $option_name, status: "updated"}'
end
# ── Prerequisites ─────────────────────────────────────────────────────────────

function _backend_github_check_prerequisites
    not command -v "$GH_CLI" >/dev/null 2>&1; and die "$GH_CLI not found in PATH. Use --cli or set GH_CLI."
    not command -v jq >/dev/null 2>&1; and die "jq not found in PATH."
    $GH_CLI api user >/dev/null 2>&1; or die "Not authenticated with $GH_CLI."
end
