{
  config,
  pkgs,
  lib,
  inputs,
  ...
}: {
  imports = [./oh-my-openagent.nix];

  options.modules.opencode = with lib; {
    preSetupScripts = mkOption {
      type = types.listOf types.str;
      default = [];
      description = "Shell scripts to source before running OpenCode";
    };

    runtimeInputs = mkOption {
      type = types.listOf types.package;
      default = [];
      description = "Additional packages to add to PATH inside the jail";
    };

    persistentDirs = mkOption {
      type = types.listOf types.str;
      default = ["~/.worktrees" "~/.cache"];
      description = ''
        Host directories bind-mounted read-write into the OpenCode jail at the
        same path. These live on real disk (btrfs), so they survive reboots
        and aren't capped by the jail's 16G home tmpfs. Created at runtime if
        missing. Tilde-expanded by the shell.

        Defaults cover the two paths that historically filled the tmpfs:
          - ~/.worktrees  — git worktrees created by the using-git-worktrees skill
          - ~/.cache      — XDG cache (nix fetcher cache, etc.); replaces the
            XDG_CACHE_HOME=/tmp/nixcache hack from the shared-yubikey-usbip session
      '';
    };
  };

  config = let
    cfg = config.modules.opencode;
    jail = inputs.jail-nix.lib.init pkgs;

    opencode-pkg =
      inputs.llm-agents.packages.${pkgs.stdenv.hostPlatform.system}.opencode;

    settingsJSON = builtins.toJSON config.programs.opencode.settings;

    jailed-opencode = jail "opencode" opencode-pkg (
      with jail.combinators;
        [
          network
          no-new-session
          (share-ns "pid")
          mount-cwd
          (ro-bind "/nix/store" "/nix/store")
          time-zone
          fake-passwd
          (add-runtime "mkdir -p \"$HOME/.local/share/opencode/tmp\"")
          (rw-bind (noescape "~/.local/share/opencode/tmp") "/tmp")
          (try-readwrite (noescape "~/.cache/opencode"))
          (try-readwrite (noescape "~/.config/opencode"))
          (try-readwrite (noescape "~/.local/share/opencode"))
          (try-readonly (noescape "~/.config/git"))
          (try-readonly (noescape "~/.gitconfig"))
          (try-readonly (noescape "~/.ssh"))
          (try-readwrite (noescape "~/.claude"))
          (try-readwrite (noescape "~/.cache/ck"))
          (try-readonly "/run/secrets")
          (try-readonly (noescape "~/.1password/agent.sock"))
          (try-fwd-env "ANTHROPIC_API_KEY")
          (try-fwd-env "OPENAI_API_KEY")
          (try-fwd-env "CONTEXT7_API_KEY")
          (fwd-env "OPENCODE_CONFIG_CONTENT")
          (try-fwd-env "NIX_CONFIG")
          (try-fwd-env "SSL_CERT_FILE")
          (try-fwd-env "COLORTERM")
          (add-pkg-deps ([
              pkgs.nixd
              pkgs.fish-lsp
              pkgs.git
              pkgs.openssh
              pkgs.ripgrep
              pkgs.bash
              pkgs.fish
              pkgs._1password-gui
              pkgs.curl
              pkgs.gnused
              pkgs.gawk
              pkgs.util-linux
              pkgs.alejandra
              pkgs.cacert
              pkgs.nodejs
            ]
            ++ cfg.runtimeInputs))
        ]
        # Persistent real-disk bind-mounts (override the tmpfs-backed home for
        # build-heavy paths). See modules.opencode.persistentDirs.
        ++ (builtins.concatMap (
            dir: [
              (add-runtime "mkdir -p \"${builtins.replaceStrings ["~"] ["$HOME"] dir}\"")
              (rw-bind (noescape dir) (noescape dir))
            ]
          )
          cfg.persistentDirs)
    );

    opencode-wrapper = pkgs.writeShellApplication {
      name = "opencode";
      runtimeInputs = [jailed-opencode];
      checkPhase = "true";
      text = ''
        ${lib.concatMapStrings (script: ''
            . ${script}
          '')
          cfg.preSetupScripts}

        export NIX_CONFIG="experimental-features = nix-command flakes"
        export NIX_PATH="nixpkgs=${inputs.nixpkgs}"
        export SSL_CERT_FILE="${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt"
        export OPENCODE_CONFIG_CONTENT='${settingsJSON}'
        exec ${lib.getExe jailed-opencode} "$@"
      '';
    };
  in
    lib.mkIf config.programs.opencode.enable {
      programs.opencode.package = lib.mkForce opencode-wrapper;
    };
}
