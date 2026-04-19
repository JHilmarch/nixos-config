{
  config,
  pkgs,
  lib,
  inputs,
  self,
  username,
  ...
}: {
  imports = [
    "${self}/home-modules/copilot-cli"
  ];

  home-manager.users.${username} = {
    modules.copilot-cli = {
      enable = true;
      runtimeInputs = [
        inputs.mcp-nixos.packages.${pkgs.stdenv.hostPlatform.system}.mcp-nixos
        pkgs.local.azure-mcp-server
        pkgs.unstable.playwright-mcp
        pkgs.unstable.mcp-proxy
        pkgs.local.azure-devops-mcp
      ];
    };
  };
}
