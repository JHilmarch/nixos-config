{
  config,
  pkgs,
  lib,
  self,
  ...
}: {
  imports = builtins.attrValues (import ../users/default.nix) ++ [./common.nix];

  services.openssh = {
    enable = true;
    settings = {
      PermitRootLogin = "prohibit-password";
      PasswordAuthentication = false;
    };
  };

  services.resolved = {
    extraConfig = ''
      Cache=true
      CacheFromLocalhost=true
    '';
  };

  environment.systemPackages = with pkgs; [
    sops
    age
  ];

  sops = {
    defaultSopsFile = "${self}/secrets/${config.networking.hostName}/secrets.yml";
    defaultSopsFormat = "yaml";
    validateSopsFiles = true;
    gnupg.sshKeyPaths = [];
  };
}
