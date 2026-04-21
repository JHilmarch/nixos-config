{
  config,
  pkgs,
  lib,
  inputs,
  self,
  ...
}: let
  sharedLib = import ../lib.nix {inherit lib;};
  sharedSkills = sharedLib.readSkillsFrom (self + "/ai/skills");
in {
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

    mcpServers = mkOption {
      type = types.attrsOf types.anything;
      default = {};
      description = "MCP server config written to ~/.copilot/mcp-config.json";
    };
  };

  config = let
    cfg = config.modules.copilot-cli;
    jail = inputs.jail-nix.lib.init pkgs;

    copilot-pkg = pkgs.github-copilot-cli;

    settingsJSON = builtins.toJSON {
      mcpServers = cfg.mcpServers;
    };

    copilot-azure-devops-mcp-wrapper = pkgs.writeShellApplication {
      name = "copilot-azure-devops-mcp";
      runtimeInputs = [
        pkgs.fish
        pkgs.coreutils
        pkgs.local.azure-devops-mcp
      ];
      checkPhase = "true";
      text = ''
        exec ${pkgs.fish}/bin/fish ${./scripts/copilot-azure-devops-mcp.fish} "$@"
      '';
    };

    jailed-copilot = jail "copilot" copilot-pkg (
      with jail.combinators; [
        network
        no-new-session
        mount-cwd
        (ro-bind "/nix/store" "/nix/store")
        time-zone
        fake-passwd
        (tmpfs "/tmp")
        (try-readwrite (noescape "~/.cache/copilot-cli"))
        (try-readwrite (noescape "~/.config/copilot-cli"))
        (try-readwrite (noescape "~/.copilot"))
        (try-readwrite (noescape "~/.local/share/copilot-cli"))
        (try-readonly (noescape "~/.config/git"))
        (try-readonly (noescape "~/.gitconfig"))
        (try-readonly (noescape "~/.ssh"))
        (try-fwd-env "GH_TOKEN")
        (try-fwd-env "GITHUB_TOKEN")
        (try-fwd-env "GH_HOST")
        (try-fwd-env "COPILOT_CLI_SETTINGS")
        (try-fwd-env "AZURE_DEVOPS_ORG")
        (try-fwd-env "AZURE_DEVOPS_PAT")
        (try-fwd-env "SSH_AUTH_SOCK")
        (add-pkg-deps ([
            pkgs.git
            pkgs.gh
            pkgs.ripgrep
            pkgs.bash
            pkgs.fish
            copilot-pkg
            pkgs.fishPlugins.github-copilot-cli-fish
            copilot-azure-devops-mcp-wrapper
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

      home.file = lib.mkMerge [
        {".copilot/mcp-config.json".text = settingsJSON;}
        (lib.mapAttrs' (name: path:
          lib.nameValuePair ".copilot/skills/${name}" {
            source = path;
            recursive = true;
          })
        sharedSkills)
      ];
    };
}
