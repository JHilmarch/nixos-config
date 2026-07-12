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
    ./forgejo.nix
    ./restic.nix
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
    "forgejo-secret-key" = {
      owner = "forgejo";
      group = "forgejo";
    };
    "forgejo-internal-token" = {
      owner = "forgejo";
      group = "forgejo";
    };
    "forgejo-db-password" = {
      owner = "forgejo";
      group = "forgejo";
    };
    "restic-forge-password" = {};
  };

  system.stateVersion = "26.05";
}
