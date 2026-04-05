# @fish-lsp-disable 4004
# markitdown-mcp — PyPI package (markitdown)
# Embedded in NixOS module, uses nix-prefetch-url for GitHub hash

function fetch_latest_markitdown-mcp
    curl -s https://pypi.org/pypi/markitdown/json | jq -r '.info.version'
end

function current_markitdown-mcp
    nix_read "modules/markitdown-mcp/default.nix" 'markitdownVersion = "([^"]+)"'
end

function update_markitdown-mcp
    set -l latest $argv[1]
    set -l file "modules/markitdown-mcp/default.nix"
    set -l toplevel ".#nixosConfigurations.nixos-orion.config.system.build.toplevel"

    sed -i -E "s|markitdownVersion = \"[^\"]+\"|markitdownVersion = \"$latest\"|" "$file"

    log_step "Computing markitdown source hash..."
    set -l hash (nix_prefetch_github_hash microsoft markitdown "v$latest"); or return 1

    # Replace only the markitdownSrc hash (second hash occurrence in the file)
    set -l src_line (grep -n 'hash = "sha256-' "$file" | sed -n '2p' | cut -d: -f1)
    if test -z "$src_line"
        log_error "Could not find markitdownSrc hash line"
        return 1
    end
    set -l expr "$src_line"'s|hash = "sha256-[^"]*"|hash = "'$hash'"|'
    sed -i $expr "$file"
    log_step "Hash updated to $hash"

    log_step "Verifying build (dry-run)..."
    nix_build_quiet "$toplevel" --dry-run
end
