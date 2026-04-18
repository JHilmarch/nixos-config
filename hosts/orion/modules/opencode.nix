{
  config,
  pkgs,
  lib,
  inputs,
  self,
  username,
  ...
}: {
  home-manager.users.${username} = {
    modules.opencode = {
      preSetupScripts = [
        "${self}/scripts/secrets-sops.sh ${config.sops.templates."agents.env".path}"
      ];
      runtimeInputs = [
        inputs.mcp-nixos.packages.${pkgs.stdenv.hostPlatform.system}.mcp-nixos
        pkgs.local.github-personal-mcp
        pkgs.local.github-work-mcp
        pkgs.alejandra # Required by native formatter (nix)
        pkgs.fish # Required by native formatter (fish)
        pkgs.mdformat # Required by native formatter (markdown)
      ];
    };

    programs.opencode = {
      enable = true;
      package = null; # Wrapper module provides the binary
      settings = {
        theme = "catppuccin";
        model = "anthropic/glm-5.1";
        small_model = "anthropic/glm-5-turbo";
        agent = {
          build.model = "anthropic/glm-5.1";
          plan.model = "anthropic/glm-5.1";
          explore.model = "anthropic/glm-5-turbo";
          compaction.model = "anthropic/glm-5.1";
          title.model = "anthropic/glm-5-turbo";
          summary.model = "anthropic/glm-5.1";
        };
        provider = {
          anthropic = {
            models = {
              "glm-5.1" = {};
              "glm-5-turbo" = {};
            };
            options = {
              apiKey = "{env:ANTHROPIC_API_KEY}";
              baseURL = "https://api.z.ai/api/anthropic/v1";
            };
          };
        };
        formatter = {
          nix = {
            command = [(lib.getExe pkgs.alejandra) "-q" "$FILE"];
            extensions = [".nix"];
          };
          fish = {
            command = ["fish" "-c" "fish_indent -w $FILE"];
            extensions = [".fish"];
          };
          markdown = {
            command = [(lib.getExe pkgs.mdformat) "$FILE"];
            extensions = [".md"];
          };
        };
        lsp = {
          nixd = {
            command = [(lib.getExe pkgs.nixd)];
            extensions = [".nix"];
          };
          fish-lsp = {
            command = [(lib.getExe pkgs.fish-lsp)];
            extensions = [".fish"];
          };
        };
        mcp = {
          mcp-nixos = {
            enabled = true;
            type = "local";
            command = ["mcp-nixos"];
          };
          github-personal = {
            enabled = true;
            type = "local";
            command = ["github-personal-mcp"];
          };
          github-work = {
            enabled = true;
            type = "local";
            command = ["github-work-mcp"];
          };
        };
      };
    };
  };
}
