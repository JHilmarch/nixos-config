{
  config,
  modulesPath,
  pkgs,
  lib,
  functions,
  username,
  hostname,
  self,
  ...
}: let
  authorizedSSHKeys = functions.ssh.getGithubKeys {
    username = "JHilmarch";
    sha256 = "be8166d2e49794c8e2fb64a6868e55249b4f2dd7cd8ecf1e40e0323fb12a2348";
  };
in {
  imports = [
    (modulesPath + "/virtualisation/proxmox-lxc.nix")
    ./nginx.nix
  ];

  nix.settings = {sandbox = false;};
  nix.settings.experimental-features = ["nix-command" "flakes"];
  proxmoxLXC = {
    manageNetwork = true;
    privileged = true;
  };

  networking = {
    hostName = hostname;
    useDHCP = false;
    nameservers = ["192.168.2.1"];
    interfaces.eth0 = {
      ipv4.addresses = [{
        address = "192.168.2.107";
        prefixLength = 24;
      }];
      ipv6.addresses = [{
        address = "fe80::be24:11ff:fe1a:6c89";
        prefixLength = 64;
      }];
    };
    defaultGateway = "192.168.2.1";
    defaultGateway6 = {
      address = "2001:9b1:26f6:2d00::164";
      interface = "eth0";
    };
  };
  services.fstrim.enable = false; # Let Proxmox host handle fstrim
  services.openssh = {
    enable = true;
    openFirewall = true;
    settings = {
      PermitRootLogin = "prohibit-password";
      PasswordAuthentication = false;
    };
  };
  # Cache DNS lookups to improve performance
  services.resolved = {
    extraConfig = ''
      Cache=true
      CacheFromLocalhost=true
    '';
  };
  environment.systemPackages = [
    pkgs.coreutils
    pkgs.git
    pkgs.vim
    pkgs.sops
    pkgs.age
  ];

  users.users.${username} = {
    isNormalUser = true;
    extraGroups = ["wheel"];
    openssh.authorizedKeys.keys = authorizedSSHKeys;
  };

  sops = {
    defaultSopsFile = "${self}/secrets/${hostname}/secrets.yml";
    defaultSopsFormat = "yaml";
    validateSopsFiles = true;
    gnupg.sshKeyPaths = [];
  };

  system.stateVersion = "25.11";
}
