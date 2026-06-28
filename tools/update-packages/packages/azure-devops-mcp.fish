# @fish-lsp-disable 4004 7001
# azure-devops-mcp — GitHub releases (microsoft/azure-devops-mcp)
# 4004: fns dispatched dynamically by update-packages.fish (current_$pkg etc).
# 7001: helpers nix_read / nix_fix_hash / nix_build_quiet / log_step live in
#   lib/nix.fish and common/log.fish, sourced at runtime; fish-lsp 1.1.3
#   doesn't follow dynamic `source` paths.
# Dual hash: source hash + npmDepsHash

function fetch_latest_azure-devops-mcp
    curl -s https://api.github.com/repos/microsoft/azure-devops-mcp/releases/latest | jq -r '.tag_name' | sed 's/^v//'
end

function current_azure-devops-mcp
    nix_read "packages/azure-devops-mcp/default.nix" 'version = "([^"]+)"'
end

function update_azure-devops-mcp
    set -l latest $argv[1]
    set -l file "packages/azure-devops-mcp/default.nix"
    set -l attr ".#azure-devops-mcp"

    sed -i -E "s|version = \"[^\"]+\"|version = \"$latest\"|" "$file"

    log_step "Fixing source hash..."
    nix_fix_hash "$file" 'hash = "sha256-[^"]*"' "$attr"; or return 1

    log_step "Fixing npmDepsHash..."
    sed -i -E 's|npmDepsHash = "sha256-[^"]*"|npmDepsHash = ""|' "$file"
    set -l output (nix build "$attr" 2>&1; or true)
    set -l hash (echo "$output" | grep -oE 'got: +sha256-[A-Za-z0-9+/=]+' | head -1 | sed 's/got: *//')
    test -z "$hash"; and return 1
    sed -i -E "s|npmDepsHash = \"\"|npmDepsHash = \"$hash\"|" "$file"

    log_step "Verifying build..."
    nix_build_quiet "$attr"
end
