{
  callPackage,
  awesome-copilot,
  mcp-nuget,
  azure-mcp-server,
  github-mcp-server,
}: {
  context7-mcp = callPackage ./context7-mcp {};
  awesome-copilot = awesome-copilot;
  mcp-nuget = mcp-nuget;
  azure-mcp-server = azure-mcp-server;
  github-mcp-server = github-mcp-server;
}
