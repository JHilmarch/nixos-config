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
    enable = mkEnableOption "GitHub Copilot CLI with fence sandbox";

    preSetupScripts = mkOption {
      type = types.listOf types.str;
      default = [];
      description = "Shell scripts to source before running Copilot CLI";
    };

    runtimeInputs = mkOption {
      type = types.listOf types.package;
      default = [];
      description = "Additional packages to add to PATH for Copilot CLI";
    };

    mcpServers = mkOption {
      type = types.attrsOf types.anything;
      default = {};
      description = "MCP server config written to ~/.copilot/mcp-config.json";
    };
  };

  config = let
    cfg = config.modules.copilot-cli;

    fence-pkg =
      inputs.llm-agents.packages.${pkgs.stdenv.hostPlatform.system}.fence;
    copilot-pkg =
      inputs.llm-agents.packages.${pkgs.stdenv.hostPlatform.system}.copilot-cli;

    mcpSettingsJSON = builtins.toJSON {
      mcpServers = cfg.mcpServers;
    };

    fenceSettings = pkgs.writeText "fence.json" (builtins.toJSON {
      extends = "code";
      network = {
        allowedDomains = [
          "*.visualstudio.com"
          "dev.azure.com"
          "ssh.dev.azure.com"
        ];
        allowLocalOutbound = false;
      };
      filesystem = {
        allowRead = [
          "~/.ssh"
          "/run/secrets"
          "/run/current-system/sw"
          "/nix/store"
        ];
        allowExecute = [
          "/nix/store"
        ];
      };
      command = {
        allow = [
          "git push"
        ];
        acceptSharedBinaryCannotRuntimeDeny = [
          "chroot"
        ];
      };
    });

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

    copilot-wrapper = pkgs.writeShellApplication {
      name = "copilot-fenced";
      runtimeInputs =
        [
          fence-pkg
          copilot-pkg
          pkgs.coreutils
          pkgs.socat
          pkgs.git
          pkgs.gh
          pkgs.ripgrep
          pkgs.bash
          pkgs.fish
          pkgs.cacert
          pkgs.fishPlugins.github-copilot-cli-fish
          copilot-azure-devops-mcp-wrapper
        ]
        ++ cfg.runtimeInputs;
      checkPhase = "true";
      text = ''
        ${lib.concatMapStrings (script: ''
            . ${script}
          '')
          cfg.preSetupScripts}

        export SSL_CERT_FILE="${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt"
        export NODE_EXTRA_CA_CERTS="${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt"

        args=()
        for arg in "$@"; do
          if [ "$arg" = "--debug" ]; then
            args+=("--log-level" "debug")
          else
            args+=("$arg")
          fi
        done

        exec fence --settings ${fenceSettings} -- copilot "''${args[@]}"
      '';
    };
  in
    lib.mkIf cfg.enable {
      home.packages = [copilot-wrapper copilot-pkg];

      home.file = lib.mkMerge [
        {".copilot/mcp-config.json".text = mcpSettingsJSON;}
        (lib.mapAttrs' (name: path:
          lib.nameValuePair ".copilot/skills/${name}" {
            source = path;
            recursive = true;
          })
        sharedSkills)
      ];
    };
}
