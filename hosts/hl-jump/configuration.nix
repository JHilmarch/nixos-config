{
  config,
  modulesPath,
  pkgs,
  lib,
  functions,
  username,
  ...
}: let
  authorizedSSHKeys = functions.ssh.getGithubKeys {
    username = "JHilmarch";
    sha256 = "be8166d2e49794c8e2fb64a6868e55249b4f2dd7cd8ecf1e40e0323fb12a2348";
  };
in {
  imports = [(modulesPath + "/virtualisation/proxmox-lxc.nix")];
  nix.settings = {sandbox = false;};
  nix.settings.experimental-features = ["nix-command" "flakes"];
  proxmoxLXC = {
    manageNetwork = false;
    privileged = true;
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
  ];

  users.users.${username} = {
    isNormalUser = true;
    extraGroups = ["wheel"];
    openssh.authorizedKeys.keys = authorizedSSHKeys;
  };

  system.stateVersion = "25.11";
}
