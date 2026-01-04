{
  self,
  config,
  username,
  pkgs,
  hostname,
  lib,
  ...
}: let
  claude-with-secrets = pkgs.writeShellApplication {
    name = "claude";
    runtimeInputs = [pkgs.unstable.claude-code];
    text = ''
      # shellcheck disable=SC1091
      source ${config.sops.templates."claude.env".path}
      export ANTHROPIC_AUTH_TOKEN
      export CONTEXT7_TOKEN
      exec claude "$@"
    '';
  };
in {
  home-manager.users."${username}" = {
    programs.claude-code = {
      enable = true;
      package = claude-with-secrets;

      settings = {
        alwaysThinkingEnabled = true;
        includeCoAuthoredBy = false;
        theme = "dark";
        env = {
          ANTHROPIC_BASE_URL = "https://api.z.ai/api/anthropic";
          API_TIMEOUT_MS = "3000000";
          ANTHROPIC_DEFAULT_OPUS_MODEL = "GLM-4.7";
          ANTHROPIC_DEFAULT_SONNET_MODEL = "GLM-4.7";
          ANTHROPIC_DEFAULT_HAIKU_MODEL = "GLM-4.5-Air";
        };
        permissions = {
          additionalDirectories = [
            "./.claude"
          ];
          allow = [
            "Edit"
            "Read(./.claude/**)"
            "Read(./.gitignore)"
            "Read(/nix/store/**)"
          ];
          ask = [
            "Bash(git push:*)"
            "Bash(rm:*)"
            "Bash(mv:*)"
          ];
          defaultMode = "acceptEdits";
          deny = [
            # Build outputs and cache
            "Read(./result/**)"
            "Read(./result-*/**)"
            "Read(./**/*.qcow2)"
            "Read(./**/*.iso)"
            "Edit(./result/**)"
            "Edit(./result-*/**)"

            # Secrets and sensitive information
            "Read(./secrets/**)"
            "Read(./.sops.yaml)"
            "Read(./**/*.age)"
            "Read(./**/*.key)"
            "Read(./**/secrets.nix)"
            "Read(./**/secrets.yaml)"
            "Edit(./secrets/**)"
            "Edit(./.sops.yaml)"
            "Edit(./**/*.age)"
            "Edit(./**/*.key)"
            "Edit(./**/secrets.nix)"
            "Edit(./**/secrets.yaml)"

            # Development environment temp files
            "Read(./.direnv/**)"
            "Read(./.env)"
            "Read(./.envrc)"
            "Edit(./.direnv/**)"
            "Edit(./.env)"
            "Edit(./.envrc)"

            # Version control
            "Read(./.git/**)"
            "Read(./.gitmodules)"
            "Edit(./.git/**)"
            "Edit(./.gitignore)"
            "Edit(./.gitmodules)"

            # Lock files
            "Read(./flake.lock)"
            "Read(./**/*.lock)"
            "Edit(./flake.lock)"
            "Edit(./**/*.lock)"

            # Temporary and backup files
            "Read(./**/*.swp)"
            "Read(./**/*.bak)"
            "Read(./**/*~)"
            "Edit(./**/*.swp)"
            "Edit(./**/*.bak)"
            "Edit(./**/*~)"

            # Logs and debugging
            "Read(./**/*.log)"
            "Read(./.debug/**)"
            "Edit(./**/*.log)"
            "Edit(./.debug/**)"

            # Cache directories
            "Read(./.cache/**)"
            "Read(./**/__pycache__/**)"
            "Edit(./.cache/**)"
            "Edit(./**/__pycache__/**)"

            # Node modules
            "Read(./node_modules/**)"
            "Edit(./node_modules/**)"

            # System files
            "Read(./**/.DS_Store)"
            "Read(./**/Thumbs.db)"
            "Edit(./**/.DS_Store)"
            "Edit(./**/Thumbs.db)"

            # IDE and editor settings
            "Read(./.idea/**)"
            "Read(./.vscode/**)"
            "Edit(./.idea/**)"
            "Edit(./.vscode/**)"

            # Archives
            "Read(./**/*.tar)"
            "Read(./**/*.tar.gz)"
            "Read(./**/*.tar.zst)"
            "Read(./**/*.tgz)"
            "Read(./**/*.zip)"
            "Read(./**/*.zst)"
            "Read(./**/*.vma)"
            "Read(./**/*.vma.zst)"
            "Edit(./**/*.tar)"
            "Edit(./**/*.tar.gz)"
            "Edit(./**/*.tar.zst)"
            "Edit(./**/*.tgz)"
            "Edit(./**/*.zip)"
            "Edit(./**/*.zst)"
            "Edit(./**/*.vma)"
            "Edit(./**/*.vma.zst)"

            # Certificates
            "Read(./**/*.pem)"
            "Read(./**/*.crt)"
            "Read(./**/*.cer)"
            "Read(./**/*.p12)"
            "Read(./**/*.pfx)"
            "Edit(./**/*.pem)"
            "Edit(./**/*.crt)"
            "Edit(./**/*.cer)"
            "Edit(./**/*.p12)"
            "Edit(./**/*.pfx)"

            # Environment files
            "Read(./.env.*)"
            "Read(./**/*.env)"
            "Edit(./.env.*)"
            "Edit(./**/*.env)"

            # Windows alternate data streams
            "Read(./**/*.Zone.Identifier)"
            "Edit(./**/*.Zone.Identifier)"

            # Dangerous commands
            "WebFetch"
            "Bash(curl:*)"
            "Bash(wget:*)"
          ];
          disableBypassPermissionsMode = "disable";
        };
      };
      mcpServers = {
        mcp-nixos = {
          type = "stdio";
          command = "mcp-nixos";
        };
        context7 = {
          type = "stdio";
          command = "context7-with-sops";
        };
        github-personal = {
          type = "stdio";
          command = "github-personal-mcp";
        };
        github-work = {
          type = "stdio";
          command = "github-work-mcp";
        };
        nuget = {
          type = "stdio";
          command = "mcp-nuget";
        };
        ms-learn = {
          type = "stdio";
          command = "mcp-proxy";
          args = [
            "--transport"
            "streamablehttp"
            "https://learn.microsoft.com/api/mcp"
          ];
        };
      };
    };
  };
}
