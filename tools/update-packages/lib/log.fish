# @fish-lsp-disable 4004
# Logging — suppressible via UPDATE_JSON flag

set -q UPDATE_JSON; or set -g UPDATE_JSON false

function log_info -d "Print info message (suppressed in JSON mode)"
    test "$UPDATE_JSON" = true; and return 0
    set_color green
    printf "INFO: %s\n" $argv
    set_color normal
end

function log_warn -d "Print warning message (suppressed in JSON mode)"
    test "$UPDATE_JSON" = true; and return 0
    set_color yellow
    printf "WARN: %s\n" $argv
    set_color normal
end

function log_error -d "Print error message (suppressed in JSON mode)"
    test "$UPDATE_JSON" = true; and return 0
    set_color red
    printf "ERROR: %s\n" $argv >&2
    set_color normal
end

function log_step -d "Print step indicator (suppressed in JSON mode)"
    test "$UPDATE_JSON" = true; and return 0
    set_color blue
    printf "  -> %s\n" $argv
    set_color normal
end
