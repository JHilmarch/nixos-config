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
    defaultGateway = "192.168.2.1";
    defaultGateway6 = {
      address = "2001:9b1:26f6:2d00::164";
      interface = "eth0";
    };
    useHostResolvConf = false;
  };

  proxmoxLXC.privileged = false;

  services = {
    resolved.enable = true;
    openssh.openFirewall = true;
    acmeWildcard.enable = true;
    nginxIngress.enable = true;
    sshHostKeyPersistence.enable = true;
  };

  system.stateVersion = "25.11";
}
