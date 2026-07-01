# @fish-lsp-disable 4004 7001
# codegraph — GitHub releases (colbymchenry/codegraph), prebuilt linux-x64 tarball
# 4004: fns dispatched dynamically by update-packages.fish (current_$pkg etc).
# 7001: helpers nix_read / nix_fix_hash / nix_build_quiet / log_step live in
#   lib/nix.fish and common/log.fish, sourced at runtime; fish-lsp 1.1.3
#   doesn't follow dynamic `source` paths.
# Single hash: the linux-x64 release tarball's SRI (fetchurl).

function fetch_latest_codegraph
    curl -s https://api.github.com/repos/colbymchenry/codegraph/releases/latest | jq -r '.tag_name' | sed 's/^v//'
end

function current_codegraph
    nix_read "packages/codegraph/default.nix" 'version = "([^"]+)"'
end

function update_codegraph
    set -l latest $argv[1]
    set -l file "packages/codegraph/default.nix"
    set -l attr ".#codegraph"

    sed -i -E "s|version = \"[^\"]+\"|version = \"$latest\"|" "$file"

    log_step "Fixing source hash..."
    nix_fix_hash "$file" 'hash = "sha256-[^"]*"' "$attr"; or return 1

    log_step "Verifying build..."
    nix_build_quiet "$attr"
end
