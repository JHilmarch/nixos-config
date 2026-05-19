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
        time-zone
        fake-passwd
        (tmpfs "/tmp")
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

        export NIX_CONFIG="experimental-features = nix-command flakes"
        export NIX_PATH="nixpkgs=${inputs.nixpkgs}"
        export SSL_CERT_FILE="${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt"
        export OPENCODE_CONFIG_CONTENT='${settingsJSON}'
        exec ${lib.getExe jailed-opencode} "$@"
      '';
    };
  in
    lib.mkIf config.programs.opencode.enable {
      home.packages = [opencode-wrapper];
    };
}
