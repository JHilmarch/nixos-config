# Patch source files for MCP stdio logging
# Usage: patchMcpLogging <tmpdir>
#
# This script modifies .NET source files to configure logging that redirects
# all console output to stderr, which is required for MCP stdio transport to
# work correctly (stdout must contain only JSON-RPC messages).
#
# Args:
#   $1 - Temporary directory containing the source to patch

patchMcpLogging() {
    local tmpdir="$1"

    # Add using statement for Microsoft.Extensions.Logging
    sed -i '1a using Microsoft.Extensions.Logging;' \
        "${tmpdir}/shared/McpSamples.Shared/Extensions/HostApplicationBuilderExtensions.cs"

    # Add ConfigureMcpLogging extension method
    awk '/public static IHost BuildApp/ {
        print ""
        print "    /// <summary>"
        print "    /// Configures logging to redirect all console output to stderr."
        print "    /// This is required for MCP stdio transport to work correctly,"
        print "    /// as stdout must contain only JSON-RPC messages."
        print "    /// </summary>"
        print "    public static IHostApplicationBuilder ConfigureMcpLogging(this IHostApplicationBuilder builder)"
        print "    {"
        print "        // Clear any existing console log providers and add one that writes to stderr"
        print "        builder.Logging.ClearProviders();"
        print "        builder.Logging.AddConsole(consoleLogOptions =>"
        print "        {"
        print "            // Configure all logs to go to stderr"
        print "            consoleLogOptions.LogToStandardErrorThreshold = LogLevel.Trace;"
        print "        });"
        print "        return builder;"
        print "    }"
        print ""
    }
    { print }' \
        "${tmpdir}/shared/McpSamples.Shared/Extensions/HostApplicationBuilderExtensions.cs" > "${tmpdir}/shared/McpSamples.Shared/Extensions/HostApplicationBuilderExtensions.cs.tmp" && \
        mv "${tmpdir}/shared/McpSamples.Shared/Extensions/HostApplicationBuilderExtensions.cs.tmp" \
           "${tmpdir}/shared/McpSamples.Shared/Extensions/HostApplicationBuilderExtensions.cs"

    # Patch Program.cs to call ConfigureMcpLogging
    awk '/Host\.CreateApplicationBuilder/ {
        print
        print ""
        print "// Configure logging for MCP stdio - redirect all logs to stderr"
        print "builder.ConfigureMcpLogging();"
        next
    }
    { print }' \
        "${tmpdir}/awesome-copilot/src/McpSamples.AwesomeCopilot.HybridApp/Program.cs" > "${tmpdir}/awesome-copilot/src/McpSamples.AwesomeCopilot.HybridApp/Program.cs.tmp" && \
        mv "${tmpdir}/awesome-copilot/src/McpSamples.AwesomeCopilot.HybridApp/Program.cs.tmp" \
           "${tmpdir}/awesome-copilot/src/McpSamples.AwesomeCopilot.HybridApp/Program.cs"
}
