{
  pkgs,
  lib,
  config,
  ...
}: let
  allowedSigners = pkgs.writeText "allowed_signers" ''
    jonatan.hilmarch@cabhealthcare.se ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIMHlhh9Xa4M3RptA+810suDczhI7EEFxIGf5+Eh7S9Co
  '';
in {
  programs = {
    delta = {
      enable = true;
      enableGitIntegration = true;
      options = {
        line-numbers = true;
        side-by-side = true;
        navigate = true;
      };
    };

    git = {
      enable = true;
      package = pkgs.git;
      settings = {
        user = {
          name = "Jonatan Hilmarch";
          email = "jonatan.hilmarch@cabhealthcare.se";
          signingkey = "~/.ssh/id_ed25519_github";
        };

        push = {
          default = "current";
          autoSetupRemote = true;
        };

        merge = {
          conflictstyle = "diff3";
        };

        diff = {
          colorMoved = "default";
        };

        gpg = {
          format = "ssh";
        };

        "gpg \"ssh\"" = {
          program = "${pkgs.openssh}/bin/ssh-keygen";
          allowedSignersFile = "${allowedSigners}";
        };

        commit = {
          gpgsign = true;
        };

        "credential \"https://dev.azure.com\"" = {
          useHttpPath = true;
        };

        "url \"git@ssh.dev.azure.com:v3/\"" = {
          insteadOf = "https://dev.azure.com/";
        };

        core = {
          editor = "vim";
          hooksPath = "${config.home.homeDirectory}/.config/git/hooks";
        };
      };
    };
  };
}
