{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.services.containers.awesome-copilot;
  inherit (lib) mkEnableOption mkIf;
in {
  options.services.containers.awesome-copilot.enable =
    mkEnableOption "Awesome Copilot OCI container";

  config = mkIf cfg.enable {
    virtualisation.oci-containers.containers.awesome-copilot = {
      image = "ghcr.io/microsoft/mcp-dotnet-samples/awesome-copilot:latest";
      extraOptions = [
        "--platform=linux/amd64"
        "--restart=unless-stopped"
        "--pull=always"
      ];
    };
  };
}
