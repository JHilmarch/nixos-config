# @fish-lsp-disable 4004
# awesome-copilot — GitHub commits (microsoft/mcp-dotnet-samples)
# Tracks HEAD commit, regenerates NuGet deps from cloned csproj

function _github_commit_date -d "Get commit date from GitHub API, fallback to today"
    set -l repo $argv[1]
    set -l sha $argv[2]
    set -l date (curl -s "https://api.github.com/repos/$repo/commits/$sha" | jq -r '.commit.committer.date[:10]')
    if test -z "$date" -o "$date" = null
        set date (date +%Y-%m-%d)
    end
    echo "$date"
end

function fetch_latest_awesome-copilot
    git ls-remote https://github.com/microsoft/mcp-dotnet-samples.git HEAD | cut -f1
end

function current_awesome-copilot
    nix_read "packages/awesome-copilot/default.nix" 'rev = "([^"]+)"'
end

function update_awesome-copilot
    set -l latest $argv[1]
    set -l file "packages/awesome-copilot/default.nix"
    set -l attr ".#awesome-copilot"
    set -l short (echo "$latest" | cut -c1-12)

    set -l date (_github_commit_date microsoft/mcp-dotnet-samples $latest)

    sed -i -E "s|rev = \"[^\"]+\";|rev = \"$latest\";|" "$file"
    sed -i -E "s|version = \"[^\"]+\";|version = \"$date\";|" "$file"

    log_step "Fixing source hash..."
    nix_fix_hash "$file" 'hash = "sha256-[^"]*"' "$attr"; or return 1

    # Clone and regenerate NuGet deps
    set -l tmp (mktemp -d)
    log_step "Cloning repo to regenerate deps..."
    if test "$UPDATE_JSON" = true
        git clone --depth 1 -q https://github.com/microsoft/mcp-dotnet-samples.git "$tmp/source"; or begin
            rm -rf "$tmp"
            return 1
        end
    else
        git clone --depth 1 https://github.com/microsoft/mcp-dotnet-samples.git "$tmp/source"; or begin
            rm -rf "$tmp"
            return 1
        end
    end

    set -l csproj (find "$tmp/source" -name "*.csproj" -path "*AwesomeCopilot*" | head -1)
    if test -z "$csproj"
        rm -rf "$tmp"
        return 1
    end

    log_step "Regenerating deps.json..."
    if test "$UPDATE_JSON" = true
        nix-shell -p dotnet-sdk_10 unzip jq nix --run \
            "bash tools/update-packages/scripts/generate-nuget-deps-from-project.sh '$csproj' packages/awesome-copilot/deps.json" >/dev/null 2>&1
    else
        nix-shell -p dotnet-sdk_10 unzip jq nix --run \
            "bash tools/update-packages/scripts/generate-nuget-deps-from-project.sh '$csproj' packages/awesome-copilot/deps.json"
    end
    set -l st $status
    rm -rf "$tmp"
    test $st -ne 0; and return 1

    log_step "Verifying build..."
    nix_build_quiet "$attr"
end
