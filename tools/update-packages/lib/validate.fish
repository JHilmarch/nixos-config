# @fish-lsp-disable 4004
# Prerequisite checks — verify required commands are available

function require_cmd -d "Check that all given commands exist in PATH"
    for cmd in $argv
        if not command -v "$cmd" >/dev/null 2>&1
            log_error "Required command not found: $cmd"
            return 1
        end
    end
end
