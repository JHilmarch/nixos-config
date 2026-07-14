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
          address = "192.168.2.110";
          prefixLength = 24;
        }
      ];
    };
  };

  nix.settings = {
    max-jobs = 6;
    cores = 0;
    trusted-users = ["root" username];
  };

  services.sshHostKeyPersistence.enable = true;

  system.stateVersion = "26.05";
}
