{callPackage}: let
  awesome-copilot = callPackage ./awesome-copilot {};
in {
  context7-mcp = callPackage ./context7-mcp {};
  azure-devops-mcp = callPackage ./azure-devops-mcp {};
  inherit awesome-copilot;
  awesome-copilot-patched = callPackage ./awesome-copilot/patched.nix {inherit awesome-copilot;};
  mcp-nuget = callPackage ./nuget-mcp-server {};
  azure-mcp-server = callPackage ./azure-mcp-server {};
  github-personal-mcp = callPackage ./github-mcp-server/personal.nix {};
  github-work-mcp = callPackage ./github-mcp-server/work.nix {};
  github-mcp-server = callPackage ./github-mcp-server/gh-cli.nix {};
}
