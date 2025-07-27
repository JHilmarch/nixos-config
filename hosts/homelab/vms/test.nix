{ ... }:
{
  imports = [
    ../templates/server.nix
  ];

  networking.hostName = "test-01";
  system.stateVersion = "25.05";
}
