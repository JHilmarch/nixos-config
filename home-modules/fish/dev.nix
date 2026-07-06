{
  config,
  pkgs,
  self,
  ...
}: {
  home.packages = [pkgs.grc];

  programs.fish = {
    enable = true;
    interactiveShellInit = builtins.readFile "${self}/home-modules/fish/dev-shell-init.fish";

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

  home.file.".config/fish/conf.d/base-shell-init.fish".source = "${self}/home-modules/fish/base-shell-init.fish";
}
