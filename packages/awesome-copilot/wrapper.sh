#!@runtimeShell@
set -euo pipefail

# Get the installation directory from the wrapper's location
BIN_DIR=$(dirname "$(readlink -f "$0")")
PREFIX=$(dirname "$BIN_DIR")

# ICU for .NET globalization
export LD_LIBRARY_PATH="@icu@/lib${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
export DOTNET_SYSTEM_GLOBALIZATION_INVARIANT=0

# .NET configuration
export DOTNET_ROOT="@dotnet@"
export DOTNET_ROOT_x64="@dotnet@"
export DOTNET_MULTILEVEL_LOOKUP=0
export DOTNET_ROLL_FORWARD=LatestPatch
export DOTNET_ROLL_FORWARD_TO_PRERELEASE=0
export DOTNET_CLI_TELEMETRY_OPTOUT=1
export DOTNET_NOLOGO=1
export DOTNET_PRINT_TELEMETRY_MESSAGE=false
export PATH="@dotnet@/bin:$PATH"

# ASP.NET Core logging
export ASPNETCORE_ENVIRONMENT=Production
export ASPNETCORELogging__LogLevel__Default=Warning

exec @dotnet@/bin/dotnet "$PREFIX/lib/McpSamples.AwesomeCopilot.HybridApp.dll" "$@"
