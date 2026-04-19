{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.programs.git;
in {
  programs = {
    git = {
      enable = true;

      settings = {
        user = {
          name = "Jonatan Hilmarch";
          email = "jonatan.hilmarch@cabhealthcare.se";
        };

        pull.rebase = true;

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

        "credential \"https://dev.azure.com\"" = {
          useHttpPath = true;
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
