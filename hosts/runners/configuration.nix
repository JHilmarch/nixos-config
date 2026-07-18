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
    ./forgejo-runner.nix
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

  sops.secrets = {
    # operator stores the value as TOKEN=<registration-password>
    "forgejo-runner-token" = {};
    # operator stores the value as NVD_API_KEY=<key>
    "nvd-api-key" = {};
    # operator stores the value as FORGEJO_PR_TOKEN=<scoped-token>
    "forgejo-pr-token" = {};
    # operator stores the value as FORGEJO_ISSUE_TOKEN=<api-token>
    "forgejo-issue-token" = {};
  };

  system.stateVersion = "26.05";
}
