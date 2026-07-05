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
    ./cache.nix
    ./prewarm.nix
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
  };

  services.openssh.openFirewall = true;

  # Unprivileged so the tofu API token can set the nesting feature it needs.
  proxmoxLXC.privileged = false;

  sops.secrets."nix-cache-priv-key" = {};

  services.nix-serve = {
    enable = true;
    package = pkgs.nix-serve-ng;
    bindAddress = "127.0.0.1";
    port = 5000;
    secretKeyFile = config.sops.secrets."nix-cache-priv-key".path;
  };

  system.stateVersion = "26.05";
}
