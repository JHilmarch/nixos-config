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
      enableWaylandClipboard = true;
      useFable = true;
      modelPreference = "balanced";
      codegraphBin = "${pkgs.local.codegraph}/bin/codegraph";
      preSetupScripts = [
        "${self}/scripts/secrets-sops.sh ${config.sops.templates."agents.env".path}"
      ];
      runtimeInputs = [
        inputs.mcp-nixos.packages.${pkgs.stdenv.hostPlatform.system}.mcp-nixos
        pkgs.unstable.adrs # ADR CLI + MCP server (adrs mcp serve)
        pkgs.local.codegraph # code-intelligence MCP server (codegraph serve --mcp)
        pkgs.local.github-personal-mcp
        pkgs.local.github-work-mcp
        pkgs.local.gh-personal # GitHub CLI authenticated with PAT for personal account
        pkgs.local.github-project-manager # GitHub CLI with classic PAT for project management
        pkgs.local.project-manager # project-manager.fish wrapper (fish --no-config, bakes gh + jq)
        pkgs.local.gh-work # GitHub CLI authenticated with PAT for work account
        self.formatter.${pkgs.stdenv.hostPlatform.system} # treefmt wrapper (all formatters)
        pkgs.findutils # find, xargs, locate
        pkgs.jq # command-line JSON processor
        inputs.llm-agents.packages.${pkgs.stdenv.hostPlatform.system}.ck # hybrid code search (semantic, lexical, regex)
        pkgs.nix # nix flake check, nix build, etc.
        (pkgs.dotnetCorePackages.combinePackages [
          pkgs.dotnetCorePackages.dotnet_9.sdk
          pkgs.dotnetCorePackages.dotnet_10.sdk
        ]) # .NET SDK bundle for update-packages NuGet deps generation
      ];
    };

    programs.opencode = {
      enable = true;
      package = null; # Wrapper module provides the binary
      settings = {
        model = "zai-coding-plan/glm-5.2";
        small_model = "zai-coding-plan/glm-5-turbo";
        agent = {
          build.model = "zai-coding-plan/glm-5.2";
          plan.model = "zai-coding-plan/glm-5.2";
          explore.model = "zai-coding-plan/glm-5-turbo";
          compaction.model = "zai-coding-plan/glm-5.2";
          title.model = "zai-coding-plan/glm-5-turbo";
          summary.model = "zai-coding-plan/glm-5.2";
        };
        # API-key providers (SOPS env vars). OAuth providers (anthropic, opencode-go)
        # and first-time setup: see home-modules/opencode/README.md
        provider = {
          zai-coding-plan = {
            options = {
              apiKey = "{env:ZAI_API_KEY}";
            };
          };
          openai = {
            options = {
              apiKey = "{env:OPENAI_API_KEY}";
            };
          };
        };
        formatter = {
          treefmt = {
            command = [(lib.getExe self.formatter.${pkgs.stdenv.hostPlatform.system}) "$FILE"];
            extensions = [".nix" ".md" ".fish" ".json" ".js" ".ts" ".mjs" ".mts" ".cjs" ".cts" ".jsx" ".tsx" ".css" ".html"];
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
          adrs = {
            enabled = true;
            type = "local";
            command = ["adrs" "mcp" "serve"];
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
