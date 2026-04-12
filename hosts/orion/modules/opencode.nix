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
      "${self}/home-modules/claude/scripts/secrets-sops.sh ${config.sops.templates."claude.env".path}"
    ];

    programs.opencode = {
      enable = true;
      package = null; # Wrapper module provides the binary
      settings = {
        theme = "catppuccin";
        model = "zai-coding-plan/glm-5.1";
        small_model = "zai-coding-plan/glm-5-turbo";
        agent = {
          build.model = "zai-coding-plan/glm-5.1";
          plan.model = "zai-coding-plan/glm-5.1";
          explore.model = "zai-coding-plan/glm-5-turbo";
          compaction.model = "zai-coding-plan/glm-5.1";
          title.model = "zai-coding-plan/glm-5-turbo";
          summary.model = "zai-coding-plan/glm-5.1";
        };
        provider = {
          zai-coding-plan = {
            options = {
              apiKey = "{env:ANTHROPIC_AUTH_TOKEN}";
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
