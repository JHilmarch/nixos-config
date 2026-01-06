{
  config,
  pkgs,
  username,
  ...
}: let
  context7-wrapped = pkgs.symlinkJoin {
    name = "context7-with-sops";
    paths = [pkgs.local.context7-mcp];
    buildInputs = [pkgs.makeWrapper];
    postBuild = ''
      rm $out/bin/context7-mcp
      makeWrapper ${
        pkgs.local.context7-mcp
      }/bin/context7-mcp $out/bin/context7-with-sops \
        --set CONTEXT7_TOKEN_FILE "${config.sops.secrets.context7_pat.path}"
    '';
  };
in {
  home-manager.users."${username}" = {
    home.packages = [context7-wrapped];
  };
}
