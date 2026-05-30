{
  config,
  lib,
  pkgs,
  ...
}: let
  sshConfigText = config.home.file.".ssh/config".text;
  sshConfigFile = pkgs.writeText "ssh-config" sshConfigText;
in {
  programs.ssh = {
    enable = true;
    enableDefaultConfig = false;

    settings = {
      "ssh.dev.azure.com" = {
        IdentitiesOnly = true;
        IdentityFile = ["~/.ssh/id_rsa_azuredevops"];
        ControlMaster = "auto";
        ControlPath = "~/.ssh/S.%r@%h:%p";
        ControlPersist = "60m";
      };

      "github.com" = {
        User = "git";
        IdentitiesOnly = true;
        IdentityFile = ["~/.ssh/id_ed25519_github"];
        ControlMaster = "auto";
        ControlPath = "~/.ssh/S.%r@%h:%p";
        ControlPersist = "60m";
      };
    };
  };

  # Replace the Nix store symlink with a regular file so SSH accepts the config.
  # SSH rejects ~/.ssh/config owned by nobody (Nix store); this copies it as a user-owned file.
  # Must run after "linkGeneration" which creates the symlink.
  home.activation.fixSshConfig = lib.hm.dag.entryAfter ["linkGeneration"] ''
    run rm -f $VERBOSE_ARG ~/.ssh/config
    run cat ${sshConfigFile} > ~/.ssh/config
    run chmod 600 $VERBOSE_ARG ~/.ssh/config
  '';
}
