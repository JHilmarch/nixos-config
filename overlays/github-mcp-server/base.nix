{
  serviceName,
  patSecret,
  super,
}:
super.writeShellApplication {
  name = serviceName;

  runtimeEnv = {
    PATH = super.lib.strings.makeBinPath [
      super.findutils
      super.github-mcp-server
    ];
  };

  text = ''
    GITHUB_PERSONAL_ACCESS_TOKEN="$(xargs </run/secrets/${patSecret})"
    export GITHUB_PERSONAL_ACCESS_TOKEN
    exec github-mcp-server stdio
  '';

  meta = {
    inherit (super.github-mcp-server.meta) description homepage;
    platforms = super.lib.platforms.all;
  };
}
