{
  config,
  pkgs,
  lib,
  self,
  username,
  ...
}: {
  home-manager.users.${username} = {
    modules.opencode.preSetupScripts = [
      "${self}/scripts/secrets-sops.sh ${config.sops.templates."agents.env".path}"
    ];

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
      };
    };
  };
}
