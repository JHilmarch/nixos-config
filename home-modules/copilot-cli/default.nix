{
  config,
  pkgs,
  lib,
  inputs,
  ...
}: {
  options.modules.copilot-cli = with lib; {
    preSetupScripts = mkOption {
      type = types.listOf types.str;
      default = [];
      description = "Shell scripts to source before running GitHub Copilot CLI";
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

    jailed-copilot = jail "copilot-jailed" pkgs.github-copilot-cli (
      with jail.combinators; [
        network
        no-new-session
        mount-cwd
        (ro-bind "/nix/store" "/nix/store")
        (try-readwrite (noescape "~/.cache/copilot-cli"))
        (try-readwrite (noescape "~/.config/copilot-cli"))
        (try-readonly (noescape "~/.config/git"))
        (try-readonly (noescape "~/.gitconfig"))
        (try-readonly (noescape "~/.ssh"))
        (fwd-env "GH_TOKEN")
        (fwd-env "GITHUB_TOKEN")
        (fwd-env "SSH_AUTH_SOCK")
        (try-readonly (noescape "~/.1password/agent.sock"))
        (add-pkg-deps ([
            pkgs.git
            pkgs.gh
            pkgs.ripgrep
            pkgs.bash
            pkgs.github-copilot-cli
            pkgs.fishPlugins.github-copilot-cli-fish
          ]
          ++ cfg.runtimeInputs))
      ]
    );

    copilot-wrapper = pkgs.writeShellApplication {
      name = "copilot-jailed";
      runtimeInputs = [jailed-copilot];
      checkPhase = "true";
      text = ''
        ${lib.concatMapStrings (script: ''
            . ${script}
          '')
          cfg.preSetupScripts}

        exec ${lib.getExe jailed-copilot} "$@"
      '';
    };
  in {
    home.packages = [copilot-wrapper];
  };
}
