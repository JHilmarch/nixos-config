{
  callPackage,
  lib,
}:
callPackage ./base.nix {
  name = "github-work-mcp";
  tokenFileName = "gh_work_pat";
  description = "GitHub MCP server wrapper for work account";
}
