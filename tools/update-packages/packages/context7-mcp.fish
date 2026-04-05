# @fish-lsp-disable 4004
# context7-mcp — npm package (@upstash/context7-mcp)
# Dual hash: source hash + pnpmDeps hash

function fetch_latest_context7-mcp
    curl -s https://registry.npmjs.org/@upstash/context7-mcp/latest | jq -r '.version'
end

function current_context7-mcp
    nix_read "packages/context7-mcp/default.nix" 'version = "([^"]+)"'
end

function update_context7-mcp
    set -l latest $argv[1]
    set -l file "packages/context7-mcp/default.nix"
    set -l attr ".#context7-mcp"

    sed -i -E "s|version = \"[^\"]+\"|version = \"$latest\"|" "$file"
    sed -i -E "s|rev = \"@upstash/context7-mcp@[^\"]+\"|rev = \"@upstash/context7-mcp@$latest\"|" "$file"

    log_step "Fixing source hash..."
    nix_fix_hash "$file" 'hash = "sha256-[^"]*"' "$attr"; or return 1

    log_step "Fixing pnpmDeps hash..."
    set -l pnpm_line (grep -n 'hash = "sha256-' "$file" | tail -1 | cut -d: -f1)
    test -n "$pnpm_line"; or return 1
    set -l expr "$pnpm_line"'s|hash = "sha256-[^"]*"|hash = ""|'
    sed -i $expr "$file"

    set -l output (nix build "$attr" 2>&1; or true)
    set -l hash (echo "$output" | grep -oE 'got: +sha256-[A-Za-z0-9+/=]+' | head -1 | sed 's/got: *//')
    test -z "$hash"; and return 1
    set -l expr2 "$pnpm_line"'s|hash = ""|hash = "'$hash'"|'
    sed -i $expr2 "$file"

    log_step "Verifying build..."
    nix_build_quiet "$attr"
end
