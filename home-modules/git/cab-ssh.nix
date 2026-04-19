{
  pkgs,
  lib,
  config,
  ...
}: {
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
        };

        user = {
          signingkey = "~/.ssh/id_ed25519_github";
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

  home.file.".config/git/hooks/commit-msg" = {
    source = ./../../hooks/commit-msg;
    executable = true;
  };
}
