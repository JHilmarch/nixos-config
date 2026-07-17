# @fish-lsp-disable 4004
#
# _backend_forgejo.fish — Forgejo REST implementation of project-manager operations
#
# Sourced by project-manager.fish; never run directly. The _op_* dispatchers
# in the main script route here when PROJECT_MANAGER_BACKEND=forgejo.
#
# Two-tier backend:
#
#   1. REST tier (FORGEJO_TOKEN) — issues, labels, milestones, dependencies.
#      Forgejo's /api/v1 has NO project/board/kanban endpoints, so the board
#      cannot be managed over REST.
#
#   2. GUI-emulation tier (FORGEJO_WEB_USER/PASS) — project boards. Forgejo's web
#      UI drives boards through server-rendered form POSTs; this backend replays
#      those exact requests over a curl web session (the approach of the reference
#      project patrickzzz/forgejo-web). Web routes require the `i_like_gitea`
#      session cookie — a PAT does NOT authenticate them — plus an `Origin` header
#      for CSRF (SameSite cookie + Origin check, no `_csrf` form field). See
#      FORGEJO-WEB-ROUTES.md for the source-verified route/form table.
#
# Env vars:
#   FORGEJO_TOKEN     Required. PAT for the REST tier (Authorization: token <PAT>).
#   FORGEJO_API_BASE  Optional. Defaults to https://forge.fileshare.se/api/v1
#   FORGEJO_WEB_USER  Required for board ops. Bot account username for web login.
#   FORGEJO_WEB_PASS  Required for board ops. Bot account password for web login.
#   FORGEJO_WEB_BASE  Optional. Web base URL; defaults to FORGEJO_API_BASE minus /api/v1.

set -q FORGEJO_API_BASE; or set -g FORGEJO_API_BASE "https://forge.fileshare.se/api/v1"
set -q FORGEJO_TOKEN; or set -g FORGEJO_TOKEN ""
set -q FORGEJO_WEB_USER; or set -g FORGEJO_WEB_USER ""
set -q FORGEJO_WEB_PASS; or set -g FORGEJO_WEB_PASS ""
set -q FORGEJO_WEB_BASE; or set -g FORGEJO_WEB_BASE ""
set -g _FORGEJO_WEB_JAR ""

# ── Shared Forgejo helpers ────────────────────────────────────────────────────

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
        "$FORGEJO_API_BASE$path" $argv | string collect)
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
        "$FORGEJO_API_BASE$path" | string collect)
    set -l parts (string split \n -- "$raw")
    set -l http_code $parts[-1]
    if test -n "$http_code"; and test "$http_code" -ge 400 2>/dev/null
        die "Forgejo API request to $path failed (HTTP $http_code). Check FORGEJO_TOKEN scopes (needs read/write for issues + repository)."
    end
    string join \n -- $parts[1..-2]
end

# ── Web-session tier (GUI emulation for project boards) ───────────────────────
# Forgejo has no REST board API; these helpers drive the web UI over a curl
# session. Web routes need the i_like_gitea cookie (a PAT does not work) and an
# Origin header for CSRF. Credentials come from FORGEJO_WEB_USER/PASS.

# Derive the web base URL (no trailing slash) from FORGEJO_WEB_BASE, else from
# FORGEJO_API_BASE with a trailing /api/v1 stripped.
function _backend_forgejo_web_base
    if test -n "$FORGEJO_WEB_BASE"
        string trim -r -c / -- "$FORGEJO_WEB_BASE"
        return
    end
    set -l base (string replace -r '/api/v1/?$' '' -- "$FORGEJO_API_BASE")
    string trim -r -c / -- "$base"
end

# Log in once per process, storing the cookie-jar path in the global
# $_FORGEJO_WEB_JAR. Dies with a clear message if web creds are missing or the
# login fails. Callers MUST invoke this as a bare statement (never inside a
# command substitution) so that a `die` reaches the terminal instead of being
# captured — then read $_FORGEJO_WEB_JAR.
function _backend_forgejo_web_login
    test -n "$_FORGEJO_WEB_JAR" -a -f "$_FORGEJO_WEB_JAR"; and return 0

    test -z "$FORGEJO_WEB_USER"; and die "Forgejo board ops require a web session: FORGEJO_WEB_USER not set (bot account username)."
    test -z "$FORGEJO_WEB_PASS"; and die "Forgejo board ops require a web session: FORGEJO_WEB_PASS not set (bot account password)."

    set -l web_base (_backend_forgejo_web_base)
    set -l jar (mktemp)

    # Prime the cookie jar (Forgejo sets a csrf cookie on the login GET).
    curl -sS -c "$jar" -b "$jar" -A "Mozilla/5.0" -o /dev/null "$web_base/user/login"

    set -l code (curl -sS -c "$jar" -b "$jar" -A "Mozilla/5.0" \
        -H "Origin: $web_base" \
        -o /dev/null -w '%{http_code}' \
        --data-urlencode "user_name=$FORGEJO_WEB_USER" \
        --data-urlencode "password=$FORGEJO_WEB_PASS" \
        --data-urlencode "remember=on" \
        "$web_base/user/login")

    # A successful login returns 303 (redirect to /) and writes the `session`
    # cookie. A failed login returns 200 with the login page re-rendered and no
    # session cookie. (Forgejo 15 dropped the Gitea-era `i_like_gitea` cookie;
    # the session carrier is now named `session`.)
    if not string match -qr session <"$jar"
        rm -f "$jar"
        die "Forgejo web login failed (HTTP $code, no session cookie). Check FORGEJO_WEB_USER/FORGEJO_WEB_PASS for the bot account at $web_base."
    end

    set -g _FORGEJO_WEB_JAR "$jar"
end

# Authenticated web GET. Args: <path>. Returns the response body; dies on >=400.
function _backend_forgejo_web_get
    set -l path "$argv[1]"
    set -l web_base (_backend_forgejo_web_base)
    _backend_forgejo_web_login
    set -l jar "$_FORGEJO_WEB_JAR"

    # -L follows redirects; %{url_effective} reports where we landed, used to
    # detect the change-password / login intercepts (a bot account with
    # MustChangePassword set, or a session that dropped). `string collect`
    # keeps curl's multi-line body as ONE string (fish command substitution
    # otherwise splits on newlines into a list, collapsing the body).
    set -l raw (curl -sS -L -b "$jar" -A "Mozilla/5.0" -w "\n%{http_code}\n%{url_effective}" \
        "$web_base$path" | string collect)
    set -l parts (string split \n -- "$raw")
    set -l url_effective $parts[-1]
    set -l http_code $parts[-2]
    if test -n "$http_code"; and test "$http_code" -ge 400 2>/dev/null
        _backend_forgejo_web_die "Forgejo web GET $path failed (HTTP $http_code)."
    end
    if string match -qi '*user/login*' -- "$url_effective"
        _backend_forgejo_web_die "Forgejo session dropped: GET $path redirected to login. Re-check FORGEJO_WEB_USER/FORGEJO_WEB_PASS."
    end
    if string match -qi '*user/settings/change_password*' -- "$url_effective"
        _backend_forgejo_web_die "Forgejo bot account has MustChangePassword set — log in once via the web UI and change the password (or clear the flag as admin), then retry. Login as $FORGEJO_WEB_USER redirected every page to change_password."
    end
    string join \n -- $parts[1..-3]
end

# Authenticated web request with a method + extra curl args (form fields, JSON
# body, headers). Args: <method> <path> [curl-args...]. Sends the Origin header
# for CSRF. Returns the body; dies on >=400.
function _backend_forgejo_web_request
    set -l method "$argv[1]"
    set -l path "$argv[2]"
    set -e argv[1..2]
    set -l web_base (_backend_forgejo_web_base)
    _backend_forgejo_web_login
    set -l jar "$_FORGEJO_WEB_JAR"

    set -l raw (curl -sS -b "$jar" -A "Mozilla/5.0" -X "$method" -w "\n%{http_code}" \
        -H "Origin: $web_base" \
        "$web_base$path" $argv | string collect)
    set -l parts (string split \n -- "$raw")
    set -l http_code $parts[-1]
    if test -n "$http_code"; and test "$http_code" -ge 400 2>/dev/null
        _backend_forgejo_web_die "Forgejo web $method $path failed (HTTP $http_code). Body: "(string join \n -- $parts[1..-2])
    end
    string join \n -- $parts[1..-2]
end

function _backend_forgejo_web_post
    _backend_forgejo_web_request POST $argv
end

function _backend_forgejo_web_put
    _backend_forgejo_web_request PUT $argv
end

function _backend_forgejo_web_delete
    _backend_forgejo_web_request DELETE $argv
end

# Fatal-error helper for the web tier. Writes the error to STDERR (never stdout)
# so it is not swallowed when web_get/web_request are called inside a command
# substitution, then exits. In JSON mode it emits a JSON error object; otherwise
# a red "Error:" line. The shared die() cannot be used here because it writes to
# stdout, which command substitution captures — the message would be lost.
function _backend_forgejo_web_die
    set -l msg "$argv[1]"
    if test "$JSON_MODE" = true
        echo '{}' | jq --arg msg "$msg" '{error: $msg}' >&2
    else
        printf '\033[31mError: %s\033[0m\n' "$msg" >&2
    end
    exit 1
end

# Unescape the handful of HTML entities that appear in scraped titles.
function _backend_forgejo_html_unescape
    string replace -a '&amp;' '&' -- "$argv[1]" \
        | string replace -a '&lt;' '<' \
        | string replace -a '&gt;' '>' \
        | string replace -a '&quot;' '"' \
        | string replace -a '&#39;' "'"
end

# Resolve the board repo (owner/repo) from a repo arg, honouring an owner
# override. Prints two lines: owner, repo.
function _backend_forgejo_board_repo
    set -l repo_arg "$argv[1]"
    # Board ops that take no repo argument fall back to the config's OWNER/REPO.
    if test -z "$repo_arg" -a -n "$OWNER" -a -n "$REPO"
        printf '%s\n%s' "$OWNER" "$REPO"
        return
    end
    set -l repo (_backend_forgejo_normalize_repo_with_owner "$repo_arg" "$argv[2]")
    set -l parts (string split '/' "$repo")
    printf '%s\n%s' "$parts[1]" "$parts[2]"
end

# Resolve an issue #number to its internal issue DB id (needed by board moves).
function _backend_forgejo_issue_internal_id
    set -l owner "$argv[1]"
    set -l repo_name "$argv[2]"
    set -l number "$argv[3]"
    set -l result (_backend_forgejo_api_get "/repos/$owner/$repo_name/issues/$number")
    set -l iid (echo "$result" | jq -r '.id // empty')
    test -z "$iid" -o "$iid" = null; and die "Issue #$number not found in $owner/$repo_name."
    echo "$iid"
end

# Scrape the projects list HTML into a JSON array of {number,title,state,url}.
# Args: <owner> <repo> <state> <html>.
function _backend_forgejo_scrape_projects
    set -l owner "$argv[1]"
    set -l repo_name "$argv[2]"
    set -l state "$argv[3]"
    set -l html "$argv[4]"
    set -l web_base (_backend_forgejo_web_base)

    set -l out '[]'
    # Each project row links to /{owner}/{repo}/projects/{id}"...>Title</a>.
    # string match -ar returns full-match then capture groups interleaved; walk
    # them in triples: [full, id, title, full, id, title, ...].
    set -l pat "href=\"/$owner/$repo_name/projects/([0-9]+)\"[^>]*>([^<]+)</a>"
    set -l matches (string match -ar $pat -- $html)
    set -l i 1
    set -l seen ""
    while test $i -le (count $matches)
        # matches: [full, id, title, full, id, title, ...] → step by 3
        set -l pid $matches[(math $i + 1)]
        set -l title (string trim -- $matches[(math $i + 2)])
        set i (math $i + 3)
        test -z "$pid"; and continue
        contains -- "$pid" $seen; and continue
        set -a seen "$pid"
        set title (_backend_forgejo_html_unescape "$title")
        set out (echo "$out" | jq \
            --argjson number "$pid" \
            --arg title "$title" \
            --arg state "$state" \
            --arg url "$web_base/$owner/$repo_name/projects/$pid" \
            '. + [{number: $number, title: $title, state: $state, url: $url}]')
    end
    echo "$out"
end

# Scrape a project view page into {id,title,columns:[{id,name,cards:[{issue_id}]}]}.
# Args: <html>.
function _backend_forgejo_scrape_columns
    set -l html "$argv[1]"

    set -l project_id (string match -r 'data-project="([0-9]+)"' -- $html)[2]
    test -z "$project_id"; and set project_id (string match -r '/projects/([0-9]+)' -- $html)[2]

    # Project title: prefer the h1/h2 in the project header, fall back to the
    # page <title> (stripped of the " - repo - Forgejo" suffix).
    set -l title (string match -r '<h[12][^>]*>\s*([^<]+?)\s*</h[12]>' -- $html)[2]
    if test -z "$title"
        set title (string match -r '<title>([^<]*)</title>' -- $html)[2]
        set title (string replace -r ' - .*' '' -- "$title")
    end
    set title (string trim -- "$title")
    set title (_backend_forgejo_html_unescape "$title")

    # Columns: extract id-list and name-list with precise anchors, then zip by
    # index (both appear once per column in document order, so they pair up).
    #   id:   class="project-column" data-id="N"
    #   name: <span class="project-column-title-label">NAME</span>
    set -l col_ids
    for m in (string match -ar 'class="project-column" data-id="([0-9]+)"' -- $html)
        string match -qr '^[0-9]+$' -- "$m"; and set -a col_ids "$m"
    end
    set -l col_names
    for m in (string match -ar 'project-column-title-label">([^<]+)</span>' -- $html)
        # string match -ar yields full-match, capture, full-match, capture, ...
        # keep only the captured (odd-positioned) entries
    end
    set -l name_matches (string match -ar 'project-column-title-label">([^<]+)</span>' -- $html)
    set -l i 2
    while test $i -le (count $name_matches)
        set -a col_names (_backend_forgejo_html_unescape (string trim -- "$name_matches[$i]"))
        set i (math $i + 2)
    end

    set -l columns '[]'
    # Split the HTML into per-column segments at each column's data-id boundary
    # so cards (data-issue) can be associated with their column. The split token
    # is the column container opening tag.
    set -l segs (string match -ar 'class="project-column" data-id="[0-9]+"' -- $html)
    set -l c 1
    while test $c -le (count $col_ids)
        set -l cid $col_ids[$c]
        set -l cname ""
        test $c -le (count $col_names); and set cname "$col_names[$c]"

        # Cards in this column = the HTML slice from this column's marker to the
        # next column's marker. Each column's marker is unique (distinct data-id),
        # so splitting on it yields [before, this-column-onward]; seg[2] is the
        # column body, trimmed at the next column's marker.
        set -l segs (string split "class=\"project-column\" data-id=\"$cid\"" -- $html)
        set -l after "$segs[2]"
        set -l slice "$after"
        if test -n "$after" -a $c -lt (count $col_ids)
            set -l next_idx (math $c + 1)
            set -l next_marker "class=\"project-column\" data-id=\"$col_ids[$next_idx]\""
            set slice (string split "$next_marker" -- $after)[1]
        end

        set -l cards '[]'
        set -l card_seen ""
        if test -n "$slice"
            for cm in (string match -ar 'data-issue="([0-9]+)"' -- $slice)
                string match -qr '^[0-9]+$' -- "$cm"; or continue
                contains -- "$cm" $card_seen; and continue
                set -a card_seen "$cm"
                set cards (echo "$cards" | jq --argjson iid "$cm" '. + [{issue_id: $iid}]')
            end
        end

        set columns (echo "$columns" | jq --argjson id "$cid" --arg name "$cname" \
            --argjson cards "$cards" \
            '. + [{id: $id, name: $name, cards: $cards}]')
        set c (math $c + 1)
    end

    echo '{}' | jq \
        --arg id "$project_id" \
        --arg title "$title" \
        --argjson columns "$columns" \
        '{id: (if $id == "" then null else ($id|tonumber) end), title: $title, columns: $columns}'
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
# ── Project-board operations (web/GUI emulation) ──────────────────────────────
# Forgejo boards map onto the GitHub-Projects CLI vocabulary as follows:
#   project        → Forgejo repo project (id == "number")
#   column         → the board's only "field": a single-select named "Status"
#   card / item    → an issue attached to the board (identified by internal id)
#   move card      → set the issue's column (update-select / set-field)
# Ops with no Forgejo equivalent (text/number/date fields) reject specifically.

function _backend_forgejo_no_board_field
    set -l op "$argv[1]"
    die "Forgejo backend: $op is not supported. Forgejo boards have no text/number/date fields — only column placement (the Status field) is available. Use update-select / set-field to move a card between columns."
end

function _backend_forgejo_list_projects
    # Args: [repo] [owner]
    _backend_forgejo_web_login
    set -l owner_repo (_backend_forgejo_board_repo "$argv[1]" "$argv[2]")
    set -l owner "$owner_repo[1]"
    set -l repo_name "$owner_repo[2]"

    set -l open_html (_backend_forgejo_web_get "/$owner/$repo_name/projects")
    set -l closed_html (_backend_forgejo_web_get "/$owner/$repo_name/projects?state=closed")
    set -l open_p (_backend_forgejo_scrape_projects "$owner" "$repo_name" open "$open_html")
    set -l closed_p (_backend_forgejo_scrape_projects "$owner" "$repo_name" closed "$closed_html")
    set -l all (echo "$open_p" | jq --argjson c "$closed_p" '. + $c')

    if test "$JSON_MODE" = true
        echo '{}' | jq --argjson projects "$all" '{projects: $projects}'
    else
        echo "$all" | jq -r '.[] | "#\(.number)\t\(.title)\t\(.state)\t\(.url)"' | column -t -s\t
    end
end

function _backend_forgejo_view_project
    # Args: <id> [repo] [owner]
    set -l id "$argv[1]"
    test -z "$id"; and die "Usage: view-project <id> [repo] [owner]"
    _backend_forgejo_web_login
    set -l owner_repo (_backend_forgejo_board_repo "$argv[2]" "$argv[3]")
    set -l owner "$owner_repo[1]"
    set -l repo_name "$owner_repo[2]"

    set -l html (_backend_forgejo_web_get "/$owner/$repo_name/projects/$id")
    set -l data (_backend_forgejo_scrape_columns "$html")
    # The scraper may miss the id from a partial page; pin it from the argument.
    set data (echo "$data" | jq --argjson id "$id" '.id = $id')

    if test "$JSON_MODE" = true
        echo "$data"
    else
        echo "$data" | jq -r '"Project #\(.id): \(.title)"'
        echo "$data" | jq -r '.columns[] | "  [\(.id)] \(.name) (\(.cards | length) cards)", (.cards[] | "      issue-id \(.issue_id)")'
    end
end

function _backend_forgejo_create_project
    # Args: <title> [repo] [owner]
    set -l title "$argv[1]"
    test -z "$title"; and die "Usage: create-project <title> [repo] [owner]"
    _backend_forgejo_web_login
    set -l owner_repo (_backend_forgejo_board_repo "$argv[2]" "$argv[3]")
    set -l owner "$owner_repo[1]"
    set -l repo_name "$owner_repo[2]"

    # template_type=1 (BasicKanban) gives Todo/In-Progress/Done columns, the
    # closest parity to a default GitHub project board. card_type=0 (TextOnly).
    _backend_forgejo_web_post "/$owner/$repo_name/projects/new" \
        --data-urlencode "title=$title" \
        --data-urlencode "content=" \
        --data-urlencode "template_type=1" \
        --data-urlencode "card_type=0" >/dev/null

    # No id is returned on the redirect; re-list and match by title (newest wins).
    set -l html (_backend_forgejo_web_get "/$owner/$repo_name/projects")
    set -l projects (_backend_forgejo_scrape_projects "$owner" "$repo_name" open "$html")
    set -l pid (echo "$projects" | jq -r --arg t "$title" 'map(select(.title == $t)) | (max_by(.number) // {}) | .number // empty')

    test -z "$pid" -o "$pid" = null; and die "Created project POST returned no redirect id and no matching project titled '$title' was found (title >100 chars, or the form was rejected)."

    set -l web_base (_backend_forgejo_web_base)
    log_success "Created project #$pid: $title"
    echo '{}' | jq --argjson number "$pid" --arg title "$title" \
        --arg url "$web_base/$owner/$repo_name/projects/$pid" \
        '{number: $number, title: $title, url: $url}'
end

function _backend_forgejo_list_fields
    # Args: <id> [repo] [owner]. Columns are exposed as one SINGLE_SELECT "Status".
    set -l id "$argv[1]"
    test -z "$id"; and die "Usage: list-fields <id> [repo] [owner]"
    _backend_forgejo_web_login
    set -l owner_repo (_backend_forgejo_board_repo "$argv[2]" "$argv[3]")
    set -l owner "$owner_repo[1]"
    set -l repo_name "$owner_repo[2]"

    set -l html (_backend_forgejo_web_get "/$owner/$repo_name/projects/$id")
    set -l data (_backend_forgejo_scrape_columns "$html")
    set -l options (echo "$data" | jq '[.columns[] | {id: (.id|tostring), name}]')

    set -l fields (echo '[]' | jq --argjson options "$options" \
        '. + [{id: "status", name: "Status", type: "SINGLE_SELECT", options: $options}]')

    if test "$JSON_MODE" = true
        echo '{}' | jq --argjson fields "$fields" '{fields: $fields}'
    else
        echo "$fields" | jq -r '.[] | "\(.id)\t\(.name)\t\(.type)", (.options[] | "    \(.id)\t\(.name)")'
    end
end

function _backend_forgejo_create_field
    # Args: <id> <name> <type> [repo] [owner]. Only SINGLE_SELECT → a new column.
    set -l id "$argv[1]"
    set -l name "$argv[2]"
    set -l type "$argv[3]"
    test -z "$id" -o -z "$name" -o -z "$type"; and die "Usage: create-field <id> <name> <type> [repo] [owner]"

    if test "$type" != SINGLE_SELECT
        die "Forgejo boards only support columns (mapped as the Status single-select field). create-field creates a column; pass type SINGLE_SELECT with the column name."
    end

    _backend_forgejo_web_login
    set -l owner_repo (_backend_forgejo_board_repo "$argv[4]" "$argv[5]")
    set -l owner "$owner_repo[1]"
    set -l repo_name "$owner_repo[2]"

    # Sorting = current column count (append to the end).
    set -l html (_backend_forgejo_web_get "/$owner/$repo_name/projects/$id")
    set -l sorting (_backend_forgejo_scrape_columns "$html" | jq '.columns | length')

    set -l resp (_backend_forgejo_web_post "/$owner/$repo_name/projects/$id" \
        --data-urlencode "title=$name" \
        --data-urlencode "sorting=$sorting" \
        --data-urlencode "color=")

    log_success "Created column '$name' in project #$id"
    echo '{}' | jq --arg name "$name" --argjson project "$id" \
        '{field: "column", name: $name, project: $project}'
end

function _backend_forgejo_add_item
    # Args: <project-number> <issue-url> [repo] [owner]
    set -l project "$argv[1]"
    set -l url "$argv[2]"
    test -z "$project" -o -z "$url"; and die "Usage: add-item <project-number> <issue-url> [repo] [owner]"
    _backend_forgejo_web_login
    set -l owner_repo (_backend_forgejo_board_repo "$argv[3]" "$argv[4]")
    set -l owner "$owner_repo[1]"
    set -l repo_name "$owner_repo[2]"

    set -l number (string match -r '/issues/([0-9]+)' -- "$url")[2]
    test -z "$number"; and die "Could not parse an issue number from URL: $url"
    set -l iid (_backend_forgejo_issue_internal_id "$owner" "$repo_name" "$number")

    _backend_forgejo_web_post "/$owner/$repo_name/issues/projects" \
        --data-urlencode "issue_ids=$iid" \
        --data-urlencode "id=$project" >/dev/null

    log_success "Added issue #$number to project #$project"
    echo '{}' | jq --argjson project "$project" --argjson issue_id "$iid" \
        --argjson number "$number" '{added: true, project: $project, issue_id: $issue_id, number: $number}'
end

function _backend_forgejo_add_item_by_id
    # Args: <project-id> <content-id>. content-id = internal issue id.
    set -l project "$argv[1]"
    set -l iid "$argv[2]"
    test -z "$project" -o -z "$iid"; and die "Usage: add-item-by-id <project-id> <content-id>"
    _backend_forgejo_web_login
    set -l owner_repo (_backend_forgejo_board_repo "" "")
    set -l owner "$owner_repo[1]"
    set -l repo_name "$owner_repo[2]"

    _backend_forgejo_web_post "/$owner/$repo_name/issues/projects" \
        --data-urlencode "issue_ids=$iid" \
        --data-urlencode "id=$project" >/dev/null

    echo '{}' | jq --argjson project "$project" --argjson issue_id "$iid" \
        '{added: true, project: $project, issue_id: $issue_id}'
end

function _backend_forgejo_remove_item
    # Args: <project-id> <item-id>. item-id = internal issue id. id=0 removes.
    set -l project "$argv[1]"
    set -l iid "$argv[2]"
    test -z "$project" -o -z "$iid"; and die "Usage: remove-item <project-id> <item-id>"
    _backend_forgejo_web_login
    set -l owner_repo (_backend_forgejo_board_repo "" "")
    set -l owner "$owner_repo[1]"
    set -l repo_name "$owner_repo[2]"

    _backend_forgejo_web_post "/$owner/$repo_name/issues/projects" \
        --data-urlencode "issue_ids=$iid" \
        --data-urlencode "id=0" >/dev/null

    echo '{}' | jq --argjson project "$project" --argjson issue_id "$iid" \
        '{removed: true, project: $project, issue_id: $issue_id}'
end

# Move a card (issue) to a target column. Shared by update-select and set-field.
# Args: <project-id> <issue-internal-id> <column-id> [owner] [repo]
function _backend_forgejo_move_card
    set -l project "$argv[1]"
    set -l iid "$argv[2]"
    set -l column "$argv[3]"
    set -l owner "$argv[4]"
    set -l repo_name "$argv[5]"

    _backend_forgejo_web_login
    if test -z "$owner" -o -z "$repo_name"
        set -l owner_repo (_backend_forgejo_board_repo "" "")
        set owner "$owner_repo[1]"
        set repo_name "$owner_repo[2]"
    end

    set -l payload (echo '{}' | jq --argjson iid "$iid" '{issues: [{issueID: $iid, sorting: 0}]}')
    _backend_forgejo_web_post "/$owner/$repo_name/projects/$project/$column/move" \
        -H "Content-Type: application/json" \
        --data-raw "$payload" >/dev/null

    echo '{}' | jq --argjson project "$project" --argjson issue_id "$iid" \
        --argjson column "$column" '{moved: true, project: $project, issue_id: $issue_id, column: $column}'
end

function _backend_forgejo_update_select
    # Args: <project-id> <item-id> <field-id> <option-id>
    # item-id = internal issue id; option-id = target column id.
    set -l project "$argv[1]"
    set -l iid "$argv[2]"
    set -l column "$argv[4]"
    test -z "$project" -o -z "$iid" -o -z "$column"; and die "Usage: update-select <project-id> <item-id> <field-id> <option-id>"
    _backend_forgejo_move_card "$project" "$iid" "$column"
end

function _backend_forgejo_update_text
    _backend_forgejo_no_board_field update-text
end

function _backend_forgejo_update_number
    _backend_forgejo_no_board_field update-number
end

function _backend_forgejo_update_date
    _backend_forgejo_no_board_field update-date
end

function _backend_forgejo_get_project_id
    # Args: <number> [owner]. For Forgejo the project id IS the number.
    set -l number "$argv[1]"
    test -z "$number"; and die "Usage: get-project-id <number> [owner]"
    if test "$JSON_MODE" = true
        echo '{}' | jq --argjson pid "$number" '{project_id: $pid}'
    else
        echo "$number"
    end
end

function _backend_forgejo_add_to_board
    # Args: <project-number> <issue-internal-id> [issue-internal-id ...]
    set -l project "$argv[1]"
    set -e argv[1]
    test -z "$project" -o (count $argv) -lt 1; and die "Usage: add-to-board <project-number> <issue-id> [issue-id ...]"
    _backend_forgejo_web_login
    set -l owner_repo (_backend_forgejo_board_repo "" "")
    set -l owner "$owner_repo[1]"
    set -l repo_name "$owner_repo[2]"

    set -l ids (string join ',' $argv)
    _backend_forgejo_web_post "/$owner/$repo_name/issues/projects" \
        --data-urlencode "issue_ids=$ids" \
        --data-urlencode "id=$project" >/dev/null

    set -l ids_json (printf '%s\n' $argv | jq -R 'tonumber' | jq -s '.')
    log_success "Added "(count $argv)" issue(s) to project #$project"
    echo '{}' | jq --argjson project "$project" --argjson issue_ids "$ids_json" \
        '{added: true, project: $project, issue_ids: $issue_ids, count: ($issue_ids | length)}'
end

function _backend_forgejo_set_field
    # Args: <project-id> <item-id> <field-name> <option-name>
    # Resolve the column named <option-name> to its id, then move the card.
    set -l project "$argv[1]"
    set -l iid "$argv[2]"
    set -l field_name "$argv[3]"
    set -l option_name "$argv[4]"
    test -z "$project" -o -z "$iid" -o -z "$option_name"; and die "Usage: set-field <project-id> <item-id> <field-name> <option-name>"

    _backend_forgejo_web_login
    set -l owner_repo (_backend_forgejo_board_repo "" "")
    set -l owner "$owner_repo[1]"
    set -l repo_name "$owner_repo[2]"

    set -l html (_backend_forgejo_web_get "/$owner/$repo_name/projects/$project")
    set -l column (_backend_forgejo_scrape_columns "$html" \
        | jq -r --arg n "$option_name" '.columns[] | select(.name == $n) | .id' | head -n1)

    test -z "$column"; and die "Column '$option_name' not found in project #$project. Run list-fields to see available columns."
    _backend_forgejo_move_card "$project" "$iid" "$column" "$owner" "$repo_name"
end
# ── Issue-level operations (REST API) ─────────────────────────────────────────

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
