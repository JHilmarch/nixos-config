self: super: {
  # Override the upstream github-mcp-server with a wrapper that injects auth token from
  # secret gh_pat
  github-mcp-server = super.writeShellApplication {
    name = "github-mcp-server";

    runtimeEnv = {
      PATH = super.lib.strings.makeBinPath [
        super.findutils
        super.github-mcp-server
      ];
    };

    text = ''
      GITHUB_PERSONAL_ACCESS_TOKEN="$(xargs </run/secrets/gh_pat)"
      export GITHUB_PERSONAL_ACCESS_TOKEN
      exec github-mcp-server stdio
    '';

    meta = {
      inherit (super.github-mcp-server.meta) description homepage;
      platforms = super.lib.platforms.all;
    };
  };
}
