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
      "*" = {
        IdentityFile = [
          "~/.ssh/id_ed25519_sk_23839166"
          "~/.ssh/id_ed25519_sk_23839165"
        ];
        IdentityAgent = "~/.1password/agent.sock";
      };

      "github.com" = {
        User = "git";
        HostName = "github.com";
        IdentitiesOnly = true;
        IdentityFile = [
          "~/.ssh/id_ed25519_sk_23839166"
          "~/.ssh/id_ed25519_sk_23839165"
        ];
        ControlMaster = "auto";
        ControlPath = "~/.ssh/S.%r@%h:%p";
        ControlPersist = "60m";
      };

      "forge" = {
        HostName = "192.168.2.109";
        User = "forgejo";
        Port = 22;
        IdentitiesOnly = true;
        IdentityFile = [
          "~/.ssh/id_ed25519_sk_23839166_forge_fileshare_se"
          "~/.ssh/id_ed25519_sk_23839165_forge_fileshare_se"
        ];
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
