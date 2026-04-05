# @fish-lsp-disable 4004
# nuget-mcp-server — NuGet tool (NuGet.Mcp.Server)
# Uses generate-nuget-deps.sh for deps regeneration

function fetch_latest_nuget-mcp-server
    fetch_latest_nuget nuget.mcp.server
end

function current_nuget-mcp-server
    jq -r '.[] | select(.name | ascii_downcase == "nuget.mcp.server") | .version' packages/nuget-mcp-server/deps.json | head -1
end

function update_nuget-mcp-server
    set -l latest $argv[1]
    set -l attr ".#mcp-nuget"

    update_nuget_deps \
        nuget.mcp.server:nuget.mcp.server.linux-x64 NuGet.Mcp.Server $latest \
        packages/nuget-mcp-server/deps.json; or return 1

    log_step "Verifying build..."
    nix_build_quiet "$attr"
end
