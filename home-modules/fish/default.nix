{
  pkgs,
  config,
  ...
}: {
  programs.fish = {
    enable = true;
    interactiveShellInit = ''
      set fish_greeting # Disable greeting
      set -gx EDITOR vim

      if test -n "$XDG_RUNTIME_DIR"
        set -gx DOCKER_HOST "unix://$XDG_RUNTIME_DIR/docker.sock"
      end

      if test -f "/run/secrets/gh_personal_pat"
        set -gx GH_TOKEN (string trim (cat /run/secrets/gh_personal_pat))
      end
    '';

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
