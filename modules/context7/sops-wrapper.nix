{
  config,
  pkgs,
  username,
  ...
}: let
  context7-with-sops = pkgs.writeShellApplication {
    name = "context7-with-sops";
    runtimeInputs = [pkgs.context7];
    text = ''exec ${pkgs.context7}/bin/context7 --api-key "$(cat ${config.sops.secrets.context7_pat.path})" "$@"'';
  };
in {
  home-manager.users."${username}" = {
    home.packages = [context7-with-sops];
  };
}
