{pkgs, ...}: {
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
          email = "JHilmarch@users.noreply.github.com";
          name = "Jonatan Hilmarch";
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

        user = {
          signingkey = "304CB5F9C479DFFA";
        };

        commit = {
          gpgsign = true;
        };

        core.editor = "vim";
      };
    };
  };
}
