# @fish-lsp-disable 4004
# Logging — suppressible via JSON_MODE flag

set -q JSON_MODE; or set -g JSON_MODE false

function log_info -d "Print info message (suppressed in JSON mode)"
    test "$JSON_MODE" = true; and return 0
    set_color green
    printf "INFO: %s\n" "$argv" >&2
    set_color normal
end

function log_warn -d "Print warning message (suppressed in JSON mode)"
    test "$JSON_MODE" = true; and return 0
    set_color yellow
    printf "WARN: %s\n" "$argv" >&2
    set_color normal
end

function log_error -d "Print error message (suppressed in JSON mode)"
    test "$JSON_MODE" = true; and return 0
    set_color red
    printf "ERROR: %s\n" "$argv" >&2
    set_color normal
end

function log_step -d "Print step indicator (suppressed in JSON mode)"
    test "$JSON_MODE" = true; and return 0
    set_color blue
    printf "  -> %s\n" "$argv" >&2
    set_color normal
end

function log_success -d "Print success message (suppressed in JSON mode)"
    test "$JSON_MODE" = true; and return 0
    set_color green
    printf "  ✓ %s\n" "$argv" >&2
    set_color normal
end

# Always outputs. JSON mode: {"error":"msg"} to stdout. Human mode: colored to stderr.
function die -d "Print error and exit"
    set -l msg $argv[1]
    if test "$JSON_MODE" = true
        echo '{}' | jq --arg msg "$msg" '{error: $msg}'
    else
        set_color red
        printf "Error: %s\n" "$msg" >&2
        set_color normal
    end
    exit 1
end
