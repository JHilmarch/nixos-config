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

    matchBlocks = {
      "*" = {
        identityFile = [
          "~/.ssh/id_ed25519_sk_23839166"
          "~/.ssh/id_ed25519_sk_23839165"
        ];
        extraOptions = {
          IdentityAgent = "~/.1password/agent.sock";
        };
      };

      "github.com" = {
        user = "git";
        host = "github.com";
        identitiesOnly = true;
        identityFile = [
          "~/.ssh/id_ed25519_sk_23839166"
          "~/.ssh/id_ed25519_sk_23839165"
        ];
        extraOptions = {
          ControlMaster = "auto";
          ControlPath = "~/.ssh/S.%r@%h:%p";
          ControlPersist = "60m";
        };
      };
    };
  };

  # Replace the Nix store symlink with a regular file so SSH accepts the config.
  # SSH rejects ~/.ssh/config owned by nobody (Nix store); this copies it as a user-owned file.
  home.activation.fixSshConfig = lib.hm.dag.entryAfter ["writeBoundary"] ''
    run rm -f $VERBOSE_ARG ~/.ssh/config
    run cat ${sshConfigFile} > ~/.ssh/config
    run chmod 600 $VERBOSE_ARG ~/.ssh/config
  '';
}
