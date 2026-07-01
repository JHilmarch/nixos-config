{callPackage}: {
  openchamber = callPackage ./openchamber {};
  azure-devops-mcp = callPackage ./azure-devops-mcp {};
  codegraph = callPackage ./codegraph {};
  azure-mcp-server = callPackage ./azure-mcp-server {};
  github-personal-mcp = callPackage ./github-mcp-server/personal.nix {};
  github-work-mcp = callPackage ./github-mcp-server/work.nix {};
  github-mcp-server = callPackage ./github-mcp-server/gh-cli.nix {};
  gh-personal = callPackage ./gh-cli/personal.nix {};
  gh-personal-project-manager = callPackage ./gh-cli/personal-project-manager.nix {};
  gh-work = callPackage ./gh-cli/work.nix {};
  mdformat = callPackage ./mdformat {};
}
