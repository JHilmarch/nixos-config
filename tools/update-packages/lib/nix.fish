# @fish-lsp-disable 4004
# Nix helpers — read versions, fix hashes via empty-hash trick

function nix_read -d "Extract a value from a Nix file using regex"
    set -l file $argv[1]
    set -l pattern $argv[2]
    sed -En "s/.*$pattern.*/\1/p" "$file" | head -1
end

function nix_build_quiet -d "Run nix build, suppressing output in JSON mode"
    if test "$UPDATE_JSON" = true
        nix build $argv 2>/dev/null
    else
        nix build $argv
    end
end

function nix_prefetch_github_hash -d "Compute the SRI hash for a GitHub archive (fetchFromGitHub compatible)"
    set -l owner $argv[1]
    set -l repo $argv[2]
    set -l rev $argv[3]

    set -l url "https://github.com/$owner/$repo/archive/refs/tags/$rev.tar.gz"
    set -l base32 (nix-prefetch-url --unpack "$url" 2>/dev/null)
    if test -z "$base32"
        log_error "Failed to prefetch $url"
        return 1
    end

    nix hash convert --hash-algo sha256 --to sri "$base32"
end

function nix_fix_hash -d "Fix a Nix hash by blanking it, building, and extracting the got: hash"
    set -l file $argv[1]
    set -l pattern $argv[2]
    set -l attr $argv[3]

    # Blank the hash
    sed -i -E "s|$pattern|hash = \"\"|" "$file"

    # Build to get the correct hash from the error
    set -l output (nix build "$attr" 2>&1; or true)
    set -l hash (echo "$output" | grep -oE 'got: +sha256-[A-Za-z0-9+/=]+' | head -1 | sed 's/got: *//')
    if test -z "$hash"
        log_error "Could not extract hash from build output"
        return 1
    end

    # Write the correct hash
    sed -i -E 's|hash = ""|hash = "'$hash'"|' "$file"
    log_step "Hash updated to $hash"
end
