# @fish-lsp-disable 4004 7001
# openchamber — GitHub releases (openchamber/openchamber)
# Source hash + npmDepsHash + vendored package-lock.json (regenerated per bump).
# (4004/7001 disabled: functions are dispatched dynamically and helpers are
#  sourced at runtime by update-packages.fish, invisible to static analysis.)

function fetch_latest_openchamber
    curl -s https://api.github.com/repos/openchamber/openchamber/releases/latest | jq -r '.tag_name' | sed 's/^v//'
end

function current_openchamber
    nix_read "packages/openchamber/default.nix" 'version = "([^"]+)"'
end

function update_openchamber
    set -l latest $argv[1]
    set -l file "packages/openchamber/default.nix"
    set -l lockfile "packages/openchamber/package-lock.json"
    set -l attr ".#openchamber"

    sed -i -E "s|version = \"[^\"]+\"|version = \"$latest\"|" "$file"

    log_step "Fixing source hash..."
    nix_fix_hash "$file" 'hash = "sha256-[^"]*"' "$attr"; or return 1

    # Regenerate the vendored lockfile from the new tag.
    log_step "Regenerating vendored package-lock.json for v$latest..."
    _openchamber_regenerate_lockfile "$latest" "$lockfile"; or return 1

    log_step "Fixing npmDepsHash..."
    set -l hash (_openchamber_prefetch_npmhash "$lockfile")
    if not string match -rq '^sha256-' -- "$hash"
        log_error "prefetch-npm-deps failed for $lockfile (got: '$hash')"
        return 1
    end
    sed -i -E "s|npmDepsHash = \"[^\"]*\"|npmDepsHash = \"$hash\"|" "$file"

    log_step "Verifying build..."
    nix_build_quiet "$attr"
end

# Compute npmDepsHash with prefetch-npm-deps, resolved via getFlake through the
# flake's own locked nixpkgs input so it needs no flake registry.
function _openchamber_prefetch_npmhash
    set -l lockfile $argv[1]
    set -l system (nix eval --raw --impure --expr builtins.currentSystem)
    set -l bin (nix build --no-link --print-out-paths --impure \
        --expr "(builtins.getFlake (toString ./.)).inputs.nixpkgs.legacyPackages.$system.prefetch-npm-deps")
    or return 1
    "$bin/bin/prefetch-npm-deps" "$lockfile"
end

function _openchamber_regenerate_lockfile
    set -l target_version $argv[1]
    set -l lockfile $argv[2]
    set -l script (dirname (status filename))/../scripts/regen-openchamber-lockfile.sh

    bash "$script" "$target_version" "$lockfile"
end
