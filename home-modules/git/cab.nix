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

        core.editor = "vim";
      };
    };
  };
}
