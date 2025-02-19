{pkgs, ...}: {
  programs.git = {
    enable = true;
    package = pkgs.unstable.git;
    delta.enable = true;
    delta.options = {
      line-numbers = true;
      side-by-side = true;
      navigate = true;
    };
    userEmail = "JHilmarch@users.noreply.github.com";
    userName = "Jonatan Hilmarch";
    extraConfig = {
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
    };
  };
}