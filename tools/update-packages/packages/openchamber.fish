# @fish-lsp-disable 4004 7001
# openchamber — GitHub releases (openchamber/openchamber)
# Dual hash: source hash + npmDepsHash + vendored package-lock.json.
#
# 4004 (unused local function): fetch_latest_/current_/update_openchamber are
#   dispatched dynamically by name from update-packages.fish (current_$pkg etc).
# 7001 (unknown command): helpers nix_read / nix_fix_hash / nix_build_quiet /
#   log_step / log_error live in lib/nix.fish and common/log.fish, which are
#   sourced by update-packages.fish at runtime. fish-lsp 1.1.3 doesn't follow
#   dynamic `source` paths (no `status filename`/`dirname` resolution), so the
#   helpers aren't visible at static-analysis time.
#
# If a version bump fails the npmDepsHash step because upstream changed deps,
# update_openchamber auto-regenerates the vendored package-lock.json from the
# new tag via scripts/regen-openchamber-lockfile.sh. No manual intervention.

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

    log_step "Fixing npmDepsHash..."
    sed -i -E 's|npmDepsHash = "sha256-[^"]*"|npmDepsHash = ""|' "$file"
    set -l hash (_openchamber_extract_npmhash "$attr")

    # Empty-hash trick didn't surface a `got:` line — the vendored lockfile is
    # stale for the new version (upstream added/changed/removed deps).
    # Regenerate it from the upstream tag and retry extraction.
    if test -z "$hash"
        log_step "Vendored package-lock.json is stale for v$latest — regenerating..."
        _openchamber_regenerate_lockfile "$latest" "$lockfile"; or return 1
        log_step "Retrying npmDepsHash extraction with regenerated lockfile..."
        set hash (_openchamber_extract_npmhash "$attr")
        if test -z "$hash"
            log_error "npmDepsHash still unresolvable after lockfile regen."
            return 1
        end
    end
    sed -i -E "s|npmDepsHash = \"\"|npmDepsHash = \"$hash\"|" "$file"

    log_step "Verifying build..."
    nix_build_quiet "$attr"
end

# Extract npmDepsHash via the empty-hash trick: blank the hash, run `nix build`,
# parse `got: sha256-...` from the error output. Returns 0 with empty output
# when no `got:` line is found, so the caller can detect the stale-lockfile case
# via `if test -z "$hash"` without a separate status check.
function _openchamber_extract_npmhash
    set -l attr $argv[1]
    set -l output (nix build "$attr" 2>&1; or true)
    echo "$output" | grep -oE 'got: +sha256-[A-Za-z0-9+/=]+' | head -1 | sed 's/got: *//'
end

# Regenerate the vendored packages/openchamber/package-lock.json from an upstream
# tag, applying the same workspaces override the Nix build does. Delegates to the
# bash helper at scripts/regen-openchamber-lockfile.sh. Uses `nix shell` to
# provide curl/cacert/gnutar/gzip/nodejs_24 since the user env (or agent jail)
# may not have them on PATH. Explicitly forwards a known-good CA bundle because
# the shell environment's default CA setup is unreliable here.
function _openchamber_regenerate_lockfile
    set -l target_version $argv[1]
    set -l lockfile $argv[2]
    set -l script (dirname (status filename))/../scripts/regen-openchamber-lockfile.sh
    set -l cacert_path (nix build nixpkgs#cacert --no-link --print-out-paths)
    set -l ca_file "$cacert_path/etc/ssl/certs/ca-bundle.crt"

    env SSL_CERT_FILE="$ca_file" NIX_SSL_CERT_FILE="$ca_file" \
        nix shell nixpkgs#curl nixpkgs#cacert nixpkgs#gnutar nixpkgs#gzip nixpkgs#nodejs_24 \
        -c bash "$script" "$target_version" "$lockfile"
end
