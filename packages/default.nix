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
  azure-devops-mcp = callPackage ./azure-devops-mcp {};
  github-personal-mcp = callPackage ./github-mcp/personal.nix {};
  github-work-mcp = callPackage ./github-mcp/work.nix {};
}
