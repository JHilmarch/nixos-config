{
  pkgs,
  config,
  lib,
  self,
  ...
}: {
  home.packages = [pkgs.grc];

  programs.fish = {
    enable = true;
    interactiveShellInit = builtins.readFile "${self}/home-modules/fish/base-shell-init.fish";

    plugins = with pkgs.fishPlugins; [
      {
        name = "fzf-fish";
        src = fzf-fish.src;
      }
      {
        name = "git-abbr";
        src = git-abbr.src;
      }
      {
        name = "grc";
        src = grc.src;
      }
      {
        name = "colored-man-pages";
        src = colored-man-pages.src;
      }
    ];
  };
}
