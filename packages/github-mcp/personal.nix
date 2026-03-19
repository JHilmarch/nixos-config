{
  callPackage,
  lib,
}:
callPackage ./base.nix {
  name = "github-personal-mcp";
  tokenFileName = "gh_personal_pat";
  description = "GitHub MCP server wrapper for personal account";
}
