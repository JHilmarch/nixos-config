# @fish-lsp-disable 4004
# Repository discovery — find the flake root

function find_repo_root -d "Find the git repo root containing flake.nix"
    set -l dir (pwd)
    while test "$dir" != /
        if test -f "$dir/flake.nix"
            echo "$dir"
            return 0
        end
        set dir (dirname "$dir")
    end
    log_error "Could not find flake.nix in any parent directory"
    return 1
end
