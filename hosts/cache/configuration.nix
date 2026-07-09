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
    ./prewarm.nix
    ./gc.nix
    "${self}/modules/ssh-host-key-persistence/default.nix"
    "${self}/templates/proxmox-lxc.nix"
  ];

  networking = {
    hostName = hostname;
    useDHCP = false;
    nameservers = ["192.168.2.1"];
    interfaces.eth0 = {
      ipv4.addresses = [
        {
          address = "192.168.2.108";
          prefixLength = 24;
        }
      ];
    };
    defaultGateway = "192.168.2.1";
    useHostResolvConf = false;
  };

  # The pre-warm copies every host's closure here, so the store grows without
  # bound. Auto-GC when free space drops below 10 GB, freeing down to 30 GB, so
  # recently-served paths stay hot without filling the disk.
  nix.settings = {
    min-free = 10 * 1024 * 1024 * 1024;
    max-free = 30 * 1024 * 1024 * 1024;
  };

  # Unprivileged so the tofu API token can set the nesting feature it needs.
  proxmoxLXC.privileged = false;

  sops.secrets."nix-cache-priv-key" = {};

  systemd.services.nix-serve.serviceConfig.Environment = ["HOME=/var/empty"];

  networking.firewall.allowedTCPPorts = [5000];

  services = {
    resolved.enable = true;
    openssh.openFirewall = true;
    sshHostKeyPersistence.enable = true;

    nix-serve = {
      enable = true;
      package = pkgs.nix-serve-ng;
      bindAddress = "192.168.2.108";
      port = 5000;
      secretKeyFile = config.sops.secrets."nix-cache-priv-key".path;
    };
  };

  system.stateVersion = "26.05";
}
