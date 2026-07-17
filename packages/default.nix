{
  callPackage,
  forgejo-mcp-unstable,
}: rec {
  azure-devops-mcp = callPackage ./azure-devops-mcp {};
  codegraph = callPackage ./codegraph {};
  azure-mcp-server = callPackage ./azure-mcp-server {};
  github-personal-mcp = callPackage ./github-mcp-server/personal.nix {};
  github-work-mcp = callPackage ./github-mcp-server/work.nix {};
  github-mcp-server = callPackage ./github-mcp-server/gh-cli.nix {};
  gh-personal = callPackage ./gh-cli/personal.nix {};
  gh-work = callPackage ./gh-cli/work.nix {};
  github-project-manager = callPackage ./project-manager/github.nix {};
  project-manager = callPackage ./project-manager {inherit github-project-manager;};
  forgejo-project-manager = callPackage ./project-manager/forgejo.nix {inherit project-manager;};
  forgejo-mcp = callPackage ./forgejo-mcp {forgejo-mcp-bin = forgejo-mcp-unstable;};
  mdformat = callPackage ./mdformat {};
}
