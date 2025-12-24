# Build phase for awesome-copilot
# Usage: buildPhase [useLoggingPatch]
#
# Args:
#   useLoggingPatch - Set to "true" to apply MCP logging patch, "false" to skip (default: "false")

buildPhase() {
  local useLoggingPatch="${1:-false}"

  runHook preBuild

  # The source is already in $NIX_BUILD_TOP/source, which is writable
  local buildRoot="$NIX_BUILD_TOP/source"

  # Apply logging patches if requested
  if [ "$useLoggingPatch" = "true" ]; then
    source "@patchScriptFile@"
    patchMcpLogging "$buildRoot"
  fi

  # Build (restore was already done by dotnetConfigureHook)
  @dotnet@/bin/dotnet build "$buildRoot/awesome-copilot/src/McpSamples.AwesomeCopilot.HybridApp/McpSamples.AwesomeCopilot.HybridApp.csproj" \
    -c Release --nologo --no-restore

  runHook postBuild
}
