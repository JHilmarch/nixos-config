{
  config,
  lib,
  pkgs,
  inputs,
  self,
  ...
}: let
  sharedLib = import ../lib.nix {inherit lib;};
  sharedSkills = sharedLib.readSkillsFrom (self + "/ai/skills");

  skillFiles =
    lib.mapAttrs' (name: path: {
      name = ".config/opencode/skills/${name}/SKILL.md";
      value = {source = path;};
    })
    sharedSkills;

  hunk-pkg =
    inputs.llm-agents.packages.${pkgs.stdenv.hostPlatform.system}.hunk;
  hunkReviewSkill = "${hunk-pkg}/skills/hunk-review/SKILL.md";

  # Provider model catalog. Subscription/auth/setup details: see ./README.md
  # z.ai Coding Plan (SOPS API key)
  glm = "zai-coding-plan/glm-5.2"; # Orchestrator default (Claude Opus alt)
  glmPrev = "zai-coding-plan/glm-5.1"; # Acceptable per docs; currently unused
  glmFlash = "zai-coding-plan/glm-5-turbo"; # Cheap utility
  glmVision = "zai-coding-plan/glm-5v-turbo"; # Vision (legacy fallback only)

  # Anthropic Claude Max via @ex-machina/opencode-anthropic-auth plugin (ankarhem pattern).
  # Auth + first-time setup: see ./README.md
  claudeOpus = "anthropic/claude-opus-4-8"; # Primary deep/review model
  claudeSonnet = "anthropic/claude-sonnet-4-6"; # Metis, writing, unspecified-low
  claudeHaiku = "anthropic/claude-haiku-4-5"; # Quick category

  # OpenCode Go (Kimi/Qwen/MiniMax — see README.md)
  kimi = "opencode-go/kimi-k2.7-code"; # Claude-alt, vision-capable
  qwen = "opencode-go/qwen3.7-plus"; # Gemini-alt for visual/artistry
  qwenUtil = "opencode-go/qwen3.7-plus"; # Utility fallback
  minimax = "opencode-go/minimax-m3"; # Flagship
  minimaxFast = "opencode-go/minimax-m2.7"; # Fast utility

  # OpenAI API (pay-per-usage, SOPS API key)
  gpt55 = "openai/gpt-5.5"; # Hephaestus (no fallback) + last-resort chains

  globalPromptAppend = lib.strings.removeSuffix "\n" (builtins.readFile "${self}/ai/global-prompt-append.md");

  # Agent model assignments. Design rationale: see ./README.md
  agentsBase = {
    # Communicators (Claude family) — orchestrator default per user
    sisyphus = {
      model = glm;
      fallback_models = [claudeOpus kimi];
    };
    sisyphus-junior = {
      model = glm;
      fallback_models = [claudeSonnet kimi minimax];
    };
    prometheus = {
      model = glm;
      fallback_models = [claudeOpus gpt55];
    };
    atlas = {
      model = glm;
      fallback_models = [claudeSonnet kimi];
    };

    # GPT-only (Hephaestus) — single-entry chain, no fallback. Must be gpt-5.5 not gpt-5.4.
    hephaestus = {
      model = gpt55;
      variant = "medium";
    };

    # OpenAI-defaulted → real Anthropic per user rule
    oracle = {
      model = claudeOpus;
      variant = "max";
      fallback_models = [kimi gpt55];
    };
    momus = {
      model = claudeOpus;
      variant = "max";
      fallback_models = [kimi gpt55];
    };
    metis = {
      model = claudeSonnet;
      fallback_models = [claudeOpus kimi];
    };

    # Utility tier — best OpenCode Go model (Kimi) primary. See README.md for rationale.
    librarian = {
      model = kimi;
      fallback_models = [qwenUtil minimaxFast];
    };
    explore = {
      model = kimi;
      fallback_models = [qwenUtil minimaxFast];
    };

    # Vision — Kimi K2.7-code is vision-capable (Anthropic not in this chain per docs)
    multimodal-looker = {
      model = kimi;
      fallback_models = [glmVision];
    };
  };

  # Chinese-reminder prompt_append applies to Chinese-origin providers only.
  needsPromptAppend = cfg:
    lib.hasPrefix "zai-coding-plan/" cfg.model
    || lib.hasPrefix "opencode-go/" cfg.model;

  agentsWithPromptAppend = lib.mapAttrs (_name: cfg:
    if needsPromptAppend cfg
    then cfg // {prompt_append = globalPromptAppend;}
    else cfg)
  agentsBase;

  # Category model assignments. Rationale: see ./README.md
  categoriesConfig = {
    # Gemini-defaulted → Qwen (documented Gemini substitute, NOT Claude/Kimi)
    visual-engineering = {
      model = qwen;
      fallback_models = [claudeOpus kimi];
    };
    artistry = {
      model = qwen;
      fallback_models = [claudeOpus gpt55];
    };

    # OpenAI-defaulted → real Anthropic per user rule
    ultrabrain = {
      model = claudeOpus;
      variant = "max";
      fallback_models = [kimi gpt55];
    };
    deep = {
      model = claudeOpus;
      variant = "max";
      fallback_models = [kimi gpt55];
    };
    unspecified-high = {
      model = claudeOpus;
      variant = "max";
      fallback_models = [glm kimi];
    };

    # Anthropic-defaulted categories (already Anthropic in docs chain)
    unspecified-low.model = claudeSonnet;
    quick.model = claudeHaiku;
    writing.model = claudeSonnet;
  };
in
  lib.mkIf config.programs.opencode.enable {
    programs.opencode.settings.plugin = ["oh-my-openagent" "@ex-machina/opencode-anthropic-auth"];

    home.file =
      skillFiles
      // {
        ".config/opencode/skills/hunk-review/SKILL.md".source = hunkReviewSkill;
        ".config/opencode/tui.json".text = builtins.toJSON {
          "$schema" = "https://opencode.ai/tui.json";
          theme = "catppuccin";
          leader_timeout = 2000;
          keybinds = {
            leader = "ctrl+x";
            app_exit = "ctrl+c,ctrl+d,<leader>q";
            command_list = "ctrl+p";
            editor_open = "<leader>e";
            theme_list = "<leader>t";
            sidebar_toggle = "<leader>b";
            status_view = "<leader>s";
            session_new = "<leader>n";
            session_list = "<leader>l";
            session_timeline = "<leader>g";
            session_interrupt = "escape";
            session_compact = "<leader>c";
            session_export = "<leader>x";
            session_rename = "ctrl+r";
            session_child_first = "<leader>down";
            session_child_cycle = "right";
            session_child_cycle_reverse = "left";
            session_parent = "up";
            agent_list = "<leader>a";
            agent_cycle = "tab";
            agent_cycle_reverse = "shift+tab";
            variant_cycle = "ctrl+t";
            model_list = "<leader>m";
            model_provider_list = "ctrl+a";
            model_favorite_toggle = "ctrl+f";
            model_cycle_recent = "f2";
            model_cycle_recent_reverse = "shift+f2";
            messages_page_up = "pageup,ctrl+alt+b";
            messages_page_down = "pagedown,ctrl+alt+f";
            messages_first = "ctrl+g,home";
            messages_last = "ctrl+alt+g,end";
            messages_copy = "<leader>y";
            messages_undo = "<leader>u";
            messages_redo = "<leader>r";
            messages_toggle_conceal = "<leader>h";
            input_clear = "ctrl+c";
            input_submit = "return";
            input_newline = "shift+return,ctrl+return,alt+return,ctrl+j";
            input_paste = {
              key = "ctrl+v";
              preventDefault = false;
            };
          };
        };
        ".config/opencode/tui.json".force = true;
        ".config/opencode/oh-my-openagent.json".text = builtins.toJSON {
          "$schema" = "https://raw.githubusercontent.com/code-yeongyu/oh-my-openagent/dev/assets/oh-my-opencode.schema.json";
          skills = {
            sources = [
              {
                path = "~/.config/opencode/skills";
                recursive = true;
              }
            ];
          };
          # security-research/review bind a dynamic localhost port, which nono
          # blocks — disabling them avoids a noisy startup warning. See README.md.
          disabled_skills = ["git-master" "security-research" "security-review"];

          ralph_loop = {
            enabled = true;
            default_max_iterations = 25;
          };

          # Team Mode — 12 team_* tools, shared mailbox/task list. OFF by default in OMO.
          team_mode = {
            enabled = true;
            max_parallel_members = 4;
            max_members = 8;
            tmux_visualization = false;
          };

          # Refresh models.dev capability cache at startup
          model_capabilities = {
            enabled = true;
            auto_refresh_on_start = true;
          };

          # Per-provider parallelism. Rationale: see ./README.md
          background_task = {
            providerConcurrency = {
              openai = 3;
              anthropic = 3;
              opencode-go = 5;
              "zai-coding-plan" = 5;
            };
          };

          agents = agentsWithPromptAppend;
          categories = categoriesConfig;
        };
      };
  }
