{
  config,
  pkgs,
  lib,
  inputs,
  ...
}: {
  options.modules.copilot-cli = with lib; {
    enable = mkEnableOption "GitHub Copilot CLI with jail sandbox";

    preSetupScripts = mkOption {
      type = types.listOf types.str;
      default = [];
      description = "Shell scripts to source before running Copilot CLI";
    };

    runtimeInputs = mkOption {
      type = types.listOf types.package;
      default = [];
      description = "Additional packages to add to PATH inside the jail";
    };
  };

  config = let
    cfg = config.modules.copilot-cli;
    jail = inputs.jail-nix.lib.init pkgs;

    copilot-pkg = pkgs.github-copilot-cli;

    jailed-copilot = jail "copilot" copilot-pkg (
      with jail.combinators; [
        network
        no-new-session
        mount-cwd
        (ro-bind "/nix/store" "/nix/store")
        (try-readwrite (noescape "~/.cache/copilot-cli"))
        (try-readwrite (noescape "~/.config/copilot-cli"))
        (try-readwrite (noescape "~/.local/share/copilot-cli"))
        (try-readonly (noescape "~/.config/git"))
        (try-readonly (noescape "~/.gitconfig"))
        (try-readonly (noescape "~/.ssh"))
        (fwd-env "GH_TOKEN")
        (fwd-env "GITHUB_TOKEN")
        (fwd-env "GH_HOST")
        (fwd-env "COPILOT_CLI_SETTINGS")
        (add-pkg-deps ([
            pkgs.git
            pkgs.gh
            pkgs.ripgrep
            pkgs.bash
            pkgs.fish
            copilot-pkg
            pkgs.fishPlugins.github-copilot-cli-fish
          ]
          ++ cfg.runtimeInputs))
      ]
    );

    copilot-wrapper = pkgs.writeShellApplication {
      name = "copilot-jailed";
      runtimeInputs = [jailed-copilot];
      checkPhase = "true"; # Skip shellcheck - preSetupScripts may have dynamic paths
      text = ''
        ${lib.concatMapStrings (script: ''
            . ${script}
          '')
          cfg.preSetupScripts}

        exec ${lib.getExe jailed-copilot} "$@"
      '';
    };
  in
    lib.mkIf cfg.enable {
      home.packages = [copilot-wrapper];
    };
}
