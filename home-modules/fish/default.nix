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

      if test -n "''$XDG_RUNTIME_DIR"
        set -gx DOCKER_HOST "unix://''$XDG_RUNTIME_DIR/docker.sock"
      end

      set -l gh_pat_file "''$XDG_RUNTIME_DIR/secrets/gh_personal_pat"
      if not test -f "$gh_pat_file"
        set gh_pat_file "/run/secrets/gh_personal_pat"
      end

      if test -f "$gh_pat_file"
        set -gx GH_TOKEN (string trim (cat "$gh_pat_file"))
      end

      if set -q SSH_AUTH_SOCK
        systemctl --user import-environment SSH_AUTH_SOCK 2>/dev/null

        if not systemctl --user is-active decrypt-secrets >/dev/null 2>&1
          systemctl --user start decrypt-secrets >/dev/null 2>&1
        end
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
