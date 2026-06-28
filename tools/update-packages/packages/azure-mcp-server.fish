# @fish-lsp-disable 4004 7001
# azure-mcp-server — NuGet tool (Azure.Mcp)
# 4004: fns dispatched dynamically by update-packages.fish (current_$pkg etc).
# 7001: helpers fetch_latest_nuget / update_nuget_deps / nix_build_quiet /
#   log_step live in lib/nuget.fish, lib/nix.fish, common/log.fish, sourced
#   at runtime; fish-lsp 1.1.3 doesn't follow dynamic `source` paths.
# Uses generate-nuget-deps.sh for deps regeneration

function fetch_latest_azure-mcp-server
    fetch_latest_nuget azure.mcp
end

function current_azure-mcp-server
    jq -r '.[] | select(.name | ascii_downcase == "azure.mcp") | .version' packages/azure-mcp-server/deps.json | head -1
end

function update_azure-mcp-server
    set -l latest $argv[1]
    set -l attr ".#azure-mcp-server"

    update_nuget_deps \
        azure.mcp:azure.mcp.linux-x64 Azure.Mcp $latest \
        packages/azure-mcp-server/deps.json; or return 1

    log_step "Verifying build..."
    nix_build_quiet "$attr"
end
