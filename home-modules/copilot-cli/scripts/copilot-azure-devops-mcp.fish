#!/usr/bin/env fish
# Azure DevOps MCP wrapper for Copilot CLI jail.
# Converts AZURE_DEVOPS_PAT into the base64-encoded PERSONAL_ACCESS_TOKEN
# format that azure-devops-mcp expects: base64("<user>:<pat>").
# The username is ignored by Azure DevOps, so we use "copilot" as a placeholder.

set -l org $AZURE_DEVOPS_ORG

if test -z "$org"
    echo "AZURE_DEVOPS_ORG must be set before starting Azure DevOps MCP." >&2
    exit 1
end

if test -z "$AZURE_DEVOPS_PAT"
    echo "AZURE_DEVOPS_PAT must be set before starting Azure DevOps MCP." >&2
    exit 1
end

set -gx PERSONAL_ACCESS_TOKEN (printf 'copilot:%s' $AZURE_DEVOPS_PAT | base64 | string collect -N)
exec azure-devops-mcp $org --authentication pat $argv
