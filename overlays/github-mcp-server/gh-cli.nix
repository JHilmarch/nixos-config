self: super: {
  # Override the upstream github-mcp-server with a wrapper that injects auth token
  # from GitHub CLI
  github-mcp-server = super.writeShellApplication {
    name = "github-mcp-server";

    runtimeEnv = {
      PATH = super.lib.strings.makeBinPath [
        super.gh
        super.github-mcp-server
      ];
    };

    text = ''
      GITHUB_PERSONAL_ACCESS_TOKEN=$(gh auth token)
      export GITHUB_PERSONAL_ACCESS_TOKEN
      exec github-mcp-server stdio
    '';

    meta = {
      inherit (super.github-mcp-server.meta) description homepage;
      platforms = super.lib.platforms.all;
    };
  };
}
