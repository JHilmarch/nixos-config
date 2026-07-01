{
  config,
  pkgs,
  lib,
  inputs,
  self,
  ...
}: {
  imports = [./oh-my-openagent.nix ./audit-rotate.nix];

  options.modules.opencode = with lib; {
    preSetupScripts = mkOption {
      type = types.listOf types.str;
      default = [];
      description = "Shell scripts to source before running OpenCode";
    };

    runtimeInputs = mkOption {
      type = types.listOf types.package;
      default = [];
      description = "Additional packages to add to PATH for OpenCode";
    };

    persistentDirs = mkOption {
      type = types.listOf types.str;
      default = ["~/.worktrees" "~/.cache"];
      description = ''
        Host directories that the agent needs persistent read-write access to.
        With nono (replaces the jail-nix sandbox), these paths live on the real
        disk (btrfs) — no tmpfs home in the nono model. The nono profile
        (nono-profile.jsonc) grants Landlock access; the wrapper just ensures
        the dirs exist at runtime. Tilde-expanded by the shell.
      '';
    };

    enableWaylandClipboard = mkOption {
      type = types.bool;
      default = false;
      description = ''
        Grant the OpenCode sandbox connect access to the user's Wayland
        compositor socket and add `wl-clipboard` to PATH, so OpenCode's
        "copy to clipboard" actions (the copy button on messages, Ctrl+C
        within the TUI, and auto-copy-on-select when
        OPENCODE_EXPERIMENTAL_DISABLE_COPY_ON_SELECT is unset) actually reach
        the host clipboard.

        Enable on Wayland desktop hosts. Leave disabled on non-graphical hosts
        — the launch script guards the grant with a runtime existence check on
        $XDG_RUNTIME_DIR/$WAYLAND_DISPLAY, so opencode still launches cleanly
        when started from a non-Wayland session (TTY/SSH/X11), just without
        clipboard access.

        Upstream issue: anomalyco/opencode#13984

        Security note: this grants connect()-only access to a single
        AF_UNIX socket (nono `--allow-unix-socket`), not a directory or
        compositor filesystem tree. This is the same clipboard permission
        surface flatpaks use.
      '';
    };
  };

  config = let
    cfg = config.modules.opencode;

    opencode-pkg =
      inputs.llm-agents.packages.${pkgs.stdenv.hostPlatform.system}.opencode;

    hunk-pkg =
      inputs.llm-agents.packages.${pkgs.stdenv.hostPlatform.system}.hunk;

    anthropic-auth-sync = pkgs.writeShellApplication {
      name = "opencode-anthropic-auth-sync";
      runtimeInputs = [pkgs.jq];
      checkPhase = "true";
      text = builtins.readFile "${self}/scripts/opencode-anthropic-auth-sync.sh";
    };

    settingsJSON = builtins.toJSON config.programs.opencode.settings;
    nonoProfile = "${self}/home-modules/opencode/nono-profile.jsonc";

    agentPackages =
      [
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
        pkgs.gnutar
        pkgs.gzip
        pkgs.nodejs
        pkgs.jq
        pkgs.local.mdformat
        hunk-pkg
        anthropic-auth-sync
      ]
      ++ lib.optional cfg.enableWaylandClipboard pkgs.wl-clipboard
      ++ cfg.runtimeInputs;

    # persistentDirs may use ~ for $HOME; expand it for the launch script's loop.
    persistentDirsExpanded =
      map (dir: builtins.replaceStrings ["~"] ["$HOME"] dir) cfg.persistentDirs;

    launchScript = "${self}/scripts/opencode-launch.sh";

    opencode-wrapper = pkgs.writeShellApplication {
      name = "opencode";
      runtimeInputs = [pkgs.nono] ++ agentPackages;
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

        # Clipboard: disable auto-copy-on-select so a mouse drag falls through
        # to the terminal's native selection. See README "Clipboard".
        export OPENCODE_EXPERIMENTAL_DISABLE_COPY_ON_SELECT="true"

        # Inputs consumed by opencode-launch.sh (see its header for the contract).
        export OC_NONO_PROFILE="${nonoProfile}"
        export OC_BIN="${lib.getExe opencode-pkg}"
        export OC_TUI_PORT="4099"
        export OC_PERSISTENT_DIRS="${lib.concatStringsSep "\n" persistentDirsExpanded}"
        export OC_WAYLAND_CLIPBOARD="${
          if cfg.enableWaylandClipboard
          then "1"
          else ""
        }"

        exec ${pkgs.bash}/bin/bash ${launchScript} "$@"
      '';
    };
  in
    lib.mkIf config.programs.opencode.enable {
      programs.opencode.package = lib.mkForce opencode-wrapper;
      home.packages = [pkgs.nono pkgs.jq];

      programs.fish.shellAbbrs.oc-audit = "nono audit list --command opencode";
      programs.fish.functions.oc-audit-verify =
        builtins.readFile "${self}/home-modules/opencode/oc-audit-verify.fish";
    };
}
