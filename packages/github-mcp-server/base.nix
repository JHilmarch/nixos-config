{
  lib,
  writeShellApplication,
  findutils,
  github-mcp-server,
  serviceName,
  patSecret,
}:
writeShellApplication {
  name = serviceName;

  runtimeEnv = {
    PATH = lib.strings.makeBinPath [
      findutils
      github-mcp-server
    ];
  };

  text = ''
    GITHUB_PERSONAL_ACCESS_TOKEN="$(xargs </run/secrets/${patSecret})"
    export GITHUB_PERSONAL_ACCESS_TOKEN
    exec github-mcp-server stdio
  '';

  meta = {
    inherit (github-mcp-server.meta) description homepage;
    platforms = lib.platforms.all;
  };
}
