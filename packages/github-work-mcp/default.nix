{
  lib,
  symlinkJoin,
  github-mcp-server,
  makeWrapper,
}: let
  name = "github-work-mcp";
in
  symlinkJoin {
    inherit name;
    paths = [github-mcp-server];
    buildInputs = [makeWrapper];
    postBuild = ''
      rm $out/bin/github-mcp-server
      makeWrapper ${github-mcp-server}/bin/github-mcp-server $out/bin/${name} \
        --run 'GITHUB_PERSONAL_ACCESS_TOKEN="$(cat "''${XDG_RUNTIME_DIR}/secrets/gh_work_pat" 2>/dev/null || cat "/run/user/$(id -u)/secrets/gh_work_pat" 2>/dev/null || cat /run/secrets/gh_work_pat | xargs)"'
    '';

    meta = with lib; {
      description = "GitHub MCP server wrapper for work account";
      platforms = platforms.unix;
    };
  }
