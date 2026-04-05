# @fish-lsp-disable 4004
# NuGet package helpers — version fetching and deps regeneration

function fetch_latest_nuget -d "Fetch the latest version of a NuGet package"
    set -l package_id $argv[1]
    curl -s "https://api.nuget.org/v3-flatcontainer/$package_id/index.json" | jq -r '.versions[-1]'
end

function current_nuget_version -d "Read the current version of a NuGet package from deps.json"
    set -l package_id $argv[1]
    set -l deps_file $argv[2]
    jq -r ".[] | select(.name | ascii_downcase == \"$package_id\") | .version" "$deps_file" | head -1
end

function update_nuget_deps -d "Regenerate deps.json for a NuGet tool package"
    set -l ensure_sibling $argv[1]
    set -l nuget_name $argv[2]
    set -l pkg_version $argv[3]
    set -l deps_file $argv[4]

    log_step "Regenerating deps.json..."
    if test "$UPDATE_JSON" = true
        nix-shell -p dotnet-sdk_10 unzip jq nix --run \
            "bash tools/update-packages/scripts/generate-nuget-deps.sh --ensure-sibling $ensure_sibling $nuget_name $pkg_version $deps_file" >/dev/null 2>&1
    else
        nix-shell -p dotnet-sdk_10 unzip jq nix --run \
            "bash tools/update-packages/scripts/generate-nuget-deps.sh --ensure-sibling $ensure_sibling $nuget_name $pkg_version $deps_file"
    end
end
