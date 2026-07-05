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
    "${self}/modules/acme-wildcard/default.nix"
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

  services.nix-serve = {
    enable = true;
    package = pkgs.nix-serve-ng;
    bindAddress = "127.0.0.1";
    port = 5000;
    secretKeyFile = config.sops.secrets."nix-cache-priv-key".path;
  };

  system.stateVersion = "26.05";
}
