# @fish-lsp-disable 4004 7001
# openchamber — GitHub releases (openchamber/openchamber)
# Dual hash: source hash + npmDepsHash.
#
# 4004 (unused local function): fetch_latest_/current_/update_openchamber are
#   dispatched dynamically by name from update-packages.fish (current_$pkg etc).
# 7001 (unknown command): helpers nix_read / nix_fix_hash / nix_build_quiet /
#   log_step / log_error live in lib/nix.fish and common/log.fish, which are
#   sourced by update-packages.fish at runtime. fish-lsp 1.1.3 doesn't follow
#   dynamic `source` paths (no `status filename`/`dirname` resolution), so the
#   helpers aren't visible at static-analysis time.

function fetch_latest_openchamber
    curl -s https://api.github.com/repos/openchamber/openchamber/releases/latest | jq -r '.tag_name' | sed 's/^v//'
end

function current_openchamber
    nix_read "packages/openchamber/default.nix" 'version = "([^"]+)"'
end

function update_openchamber
    set -l latest $argv[1]
    set -l file "packages/openchamber/default.nix"
    set -l attr ".#openchamber"

    sed -i -E "s|version = \"[^\"]+\"|version = \"$latest\"|" "$file"

    log_step "Fixing source hash..."
    nix_fix_hash "$file" 'hash = "sha256-[^"]*"' "$attr"; or return 1

    log_step "Fixing npmDepsHash..."
    sed -i -E 's|npmDepsHash = "sha256-[^"]*"|npmDepsHash = ""|' "$file"
    set -l output (nix build "$attr" 2>&1; or true)
    set -l hash (echo "$output" | grep -oE 'got: +sha256-[A-Za-z0-9+/=]+' | head -1 | sed 's/got: *//')
    if test -z "$hash"
        log_error "Could not extract npmDepsHash from build output."
        log_error "Upstream deps may have changed. Regenerate packages/openchamber/package-lock.json from the v$latest tag and retry."
        return 1
    end
    sed -i -E "s|npmDepsHash = \"\"|npmDepsHash = \"$hash\"|" "$file"

    log_step "Verifying build..."
    nix_build_quiet "$attr"
end
