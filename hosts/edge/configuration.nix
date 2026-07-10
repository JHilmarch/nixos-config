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
    "${self}/modules/acme-wildcard/default.nix"
    "${self}/modules/nginx-ingress/default.nix"
    "${self}/templates/proxmox-lxc.nix"
  ];

  networking = {
    hostName = hostname;
    useDHCP = false;
    interfaces.eth0 = {
      ipv4.addresses = [
        {
          address = "192.168.2.107";
          prefixLength = 24;
        }
      ];
      ipv6.addresses = [
        {
          address = "fe80::be24:11ff:fe1a:6c89";
          prefixLength = 64;
        }
      ];
    };
    defaultGateway6 = {
      address = "2001:9b1:26f6:2d00::164";
      interface = "eth0";
    };
  };

  services = {
    acmeWildcard.enable = true;

    nginxIngress = {
      enable = true;
      virtualHosts."cache.fileshare.se".proxyPass = "http://192.168.2.108:5000";
      virtualHosts."forge.fileshare.se".proxyPass = "http://192.168.2.109:3000";
    };
  };

  system.stateVersion = "25.11";
}
