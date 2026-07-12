{
  config,
  pkgs,
  lib,
  username,
  hostname,
  self,
  ...
}: {
  imports = [
    "${self}/templates/proxmox-lxc.nix"
  ];

  networking = {
    hostName = hostname;
    useDHCP = false;
    interfaces.eth0 = {
      ipv4.addresses = [
        {
          address = "192.168.2.109";
          prefixLength = 24;
        }
      ];
    };
  };

  services.sshHostKeyPersistence.enable = true;

  sops.secrets = {
    "forgejo-secret-key" = {};
    "forgejo-internal-token" = {};
    "forgejo-db-password" = {};
    "restic-forge-password" = {};
  };

  system.stateVersion = "26.05";
}
