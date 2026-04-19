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
  };

  config = let
    cfg = config.modules.opencode;
    jail = inputs.jail-nix.lib.init pkgs;

    opencode-pkg =
      inputs.llm-agents.packages.${pkgs.stdenv.hostPlatform.system}.opencode;

    settingsJSON = builtins.toJSON config.programs.opencode.settings;

    jailed-opencode = jail "opencode" opencode-pkg (
      with jail.combinators; [
        network
        no-new-session
        mount-cwd
        (ro-bind "/nix/store" "/nix/store")
        (try-readwrite (noescape "~/.cache/opencode"))
        (try-readwrite (noescape "~/.config/opencode"))
        (try-readwrite (noescape "~/.local/share/opencode"))
        (try-readonly (noescape "~/.config/git"))
        (try-readonly (noescape "~/.gitconfig"))
        (try-readonly (noescape "~/.ssh"))
        (try-readwrite (noescape "~/.claude"))
        (try-readwrite (noescape "~/.cache/ck"))
        (try-readonly "/run/secrets")
        (fwd-env "ANTHROPIC_API_KEY")
        (fwd-env "CONTEXT7_API_KEY")
        (fwd-env "OPENCODE_CONFIG_CONTENT")
        (fwd-env "SSH_AUTH_SOCK")
        (try-readonly (noescape "~/.1password/agent.sock"))
        (add-pkg-deps ([
            pkgs.nixd
            pkgs.fish-lsp
            pkgs.git
            pkgs.openssh
            pkgs.ripgrep
            pkgs.bash
            pkgs.fish
            pkgs._1password-gui
          ]
          ++ cfg.runtimeInputs))
      ]
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

        export OPENCODE_CONFIG_CONTENT='${settingsJSON}'
        exec ${lib.getExe jailed-opencode} "$@"
      '';
    };
  in
    lib.mkIf config.programs.opencode.enable {
      home.packages = [opencode-wrapper];
    };
}
