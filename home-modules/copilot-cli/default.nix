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

    mcpServers = mkOption {
      type = types.attrsOf types.anything;
      default = {};
      description = "MCP server configuration written to ~/.copilot/mcp-config.json";
    };
  };

  config = let
    cfg = config.modules.copilot-cli;
    jail = inputs.jail-nix.lib.init pkgs;

    settingsJSON = builtins.toJSON {
      mcpServers = cfg.mcpServers;
    };

    copilot-azure-devops-mcp-wrapper = pkgs.writeShellApplication {
      name = "copilot-azure-devops-mcp";
      runtimeInputs = [
        pkgs.coreutils
        pkgs.local.azure-devops-mcp
      ];
      checkPhase = "true";
      text = ''
        if [ $# -gt 0 ]; then
          org="$1"
          shift
        else
          org="${AZURE_DEVOPS_ORG:-}"
        fi

        if [ -z "$org" ]; then
          echo "AZURE_DEVOPS_ORG must be set (or passed as the first argument)." >&2
          exit 1
        fi

        if [ -z "${AZURE_DEVOPS_PAT:-}" ]; then
          echo "AZURE_DEVOPS_PAT must be set before starting Azure DevOps MCP." >&2
          exit 1
        fi

        # Azure DevOps MCP expects PERSONAL_ACCESS_TOKEN to be base64("<non-empty-user>:<pat>").
        # The username value is ignored by Azure DevOps, so we use the stable placeholder "copilot".
        export PERSONAL_ACCESS_TOKEN="$(printf 'copilot:%s' "$AZURE_DEVOPS_PAT" | base64 -w0)"
        exec ${lib.getExe pkgs.local.azure-devops-mcp} "$org" --authentication pat "$@"
      '';
    };

    jailed-copilot = jail "copilot-jailed" pkgs.github-copilot-cli (
      with jail.combinators; [
        network
        no-new-session
        mount-cwd
        (ro-bind "/nix/store" "/nix/store")
        (try-readwrite (noescape "~/.cache/copilot-cli"))
        (try-readwrite (noescape "~/.config/copilot-cli"))
        (try-readwrite (noescape "~/.copilot"))
        (try-readonly (noescape "~/.gitconfig"))
        (try-readonly (noescape "~/.ssh"))
        (fwd-env "AZURE_DEVOPS_ORG")
        (fwd-env "AZURE_DEVOPS_PAT")
        (fwd-env "SSH_AUTH_SOCK")
        (try-readonly (noescape "~/.1password/agent.sock"))
        (add-pkg-deps ([
            pkgs.git
            pkgs.gh
            pkgs.ripgrep
            pkgs.bash
            pkgs.github-copilot-cli
            pkgs.fishPlugins.github-copilot-cli-fish
            copilot-azure-devops-mcp-wrapper
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
    home.file.".copilot/mcp-config.json".text = settingsJSON;
  };
}
