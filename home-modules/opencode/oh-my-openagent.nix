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

  omo-pkg =
    inputs.llm-agents.packages.${pkgs.stdenv.hostPlatform.system}.oh-my-opencode;
  omoPlugin = "file://${omo-pkg}/lib/oh-my-opencode/dist/index.js";

  cfg = config.modules.opencode;
  useFable = cfg.useFable;
  modelPreference = cfg.modelPreference;

  glm = "zai-coding-plan/glm-5.2";
  glmPrev = "zai-coding-plan/glm-5.1";
  glmFlash = "zai-coding-plan/glm-5-turbo";
  glmVision = "zai-coding-plan/glm-5v-turbo";

  claudeFable = "anthropic/claude-fable-5";
  claudeOpus = "anthropic/claude-opus-4-8";
  claudeSonnet = "anthropic/claude-sonnet-5";
  claudeHaiku = "anthropic/claude-haiku-4-5";

  kimi = "opencode-go/kimi-k2.7-code"; # vision-capable
  qwen = "opencode-go/qwen3.7-plus";
  qwenPrev = "opencode-go/qwen3.6-plus";
  minimax = "opencode-go/minimax-m3";
  minimaxFast = "opencode-go/minimax-m2.7";
  deepseekFlash = "opencode-go/deepseek-v4-flash";

  gpt55 = "openai/gpt-5.5";

  # Claude-vs-GLM layer ordering per `modelPreference`.
  # "Per-host model options". balanced alternates by `slot`.
  claudeBeforeGlm = slot:
    if modelPreference == "anthropic"
    then true
    else if modelPreference == "zai"
    then false
    else lib.mod slot 2 == 0;

  # Premium chain: reorderable Claude + GLM layers, fixed tail.
  premium = {
    variant ? null,
    tail,
    slot ? 0,
    fable ? useFable,
    glmLayer ? [glm],
  }: let
    withVariant = attrs:
      attrs // lib.optionalAttrs (variant != null) {inherit variant;};
    # Normalize bare "provider/model" strings so the primary can carry attrs.
    toAttrs = entry:
      if builtins.isString entry
      then {model = entry;}
      else entry;
    claudeLayer =
      if fable
      then [(withVariant {model = claudeFable;}) (withVariant {model = claudeOpus;})]
      else [(withVariant {model = claudeOpus;})];
    ordered =
      if claudeBeforeGlm slot
      then claudeLayer ++ glmLayer
      else glmLayer ++ claudeLayer;
    primary = toAttrs (builtins.head ordered);
    rest = builtins.tail ordered;
  in
    primary // {fallback_models = rest ++ tail;};

  # Sonnet-primary worker chain (junior/atlas); only the Kimi/GLM fallback
  # order follows the preference.
  sonnetChain = {
    slot ? 0,
    tail ? [],
  }: {
    model = claudeSonnet;
    fallback_models =
      (
        if claudeBeforeGlm slot
        then [kimi glm]
        else [glm kimi]
      )
      ++ tail;
  };

  globalPromptAppend = lib.strings.removeSuffix "\n" (builtins.readFile "${self}/ai/global-prompt-append.md");

  # Agent → model chains.
  # sisyphus forces fable=false.
  agentsBase = {
    sisyphus = premium {
      slot = 0;
      fable = false;
      tail = [kimi];
    };
    prometheus = premium {
      slot = 1;
      tail = [gpt55];
    };
    sisyphus-junior = sonnetChain {
      slot = 2;
      tail = [minimax];
    };
    atlas = sonnetChain {slot = 3;};

    hephaestus = {
      model = gpt55; # GPT-only, no fallback
      variant = "medium";
    };

    oracle = premium {
      slot = 4;
      variant = "max";
      tail = [kimi gpt55];
    };
    momus = premium {
      slot = 5;
      variant = "max";
      tail = [kimi gpt55];
    };
    metis = {
      model = claudeSonnet;
      fallback_models = [claudeOpus kimi];
    };

    librarian =
      if claudeBeforeGlm 10
      then {
        model = claudeHaiku;
        fallback_models = [deepseekFlash glmFlash];
      }
      else {
        model = deepseekFlash;
        fallback_models = [claudeHaiku glmFlash];
      };
    explore = {
      model = minimaxFast;
      fallback_models = [claudeHaiku glmFlash];
    };

    multimodal-looker = {
      model = kimi; # vision-capable
      fallback_models = [glmVision];
    };
  };

  # prompt_append (Chinese reminder) only for Chinese-origin providers.
  needsPromptAppend = cfg:
    lib.hasPrefix "zai-coding-plan/" cfg.model
    || lib.hasPrefix "opencode-go/" cfg.model;

  agentsWithPromptAppend = lib.mapAttrs (_name: cfg:
    if needsPromptAppend cfg
    then cfg // {prompt_append = globalPromptAppend;}
    else cfg)
  agentsBase;

  # Category → model chains. Rationale: see ./README.md.
  categoriesConfig = {
    # Qwen substitutes for Gemini on visual work (no Google provider wired).
    visual-engineering = {
      model = qwen;
      fallback_models = [qwenPrev gpt55];
    };
    artistry = {
      model = qwen;
      fallback_models = [qwenPrev gpt55];
    };

    ultrabrain = premium {
      slot = 6;
      variant = "max";
      tail = [kimi gpt55];
    };
    deep = premium {
      slot = 7;
      variant = "max";
      tail = [kimi gpt55];
    };
    unspecified-high = premium {
      slot = 8;
      variant = "max";
      tail = [kimi];
    };

    unspecified-low.model = claudeSonnet;
    quick.model = claudeHaiku;
    writing.model = claudeSonnet;
  };
in
  lib.mkIf config.programs.opencode.enable {
    programs.opencode.settings.plugin = [omoPlugin "@ex-machina/opencode-anthropic-auth"];

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

          disabled_skills = ["git-master" "security-research" "security-review"];

          ralph_loop = {
            enabled = true;
            default_max_iterations = 25;
          };

          # Team Mode — 12 team_* tools, shared mailbox/task list.
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

          telemetry = false;

          # Error-driven model switching.
          runtime_fallback = {
            enabled = true;
            retry_on_errors = [402 429 500 502 503 504 529];
            max_fallback_attempts = 5;
            cooldown_seconds = 14400;
            timeout_seconds = 30;
            notify_on_fallback = true;
            restore_primary_after_cooldown = false;
          };

          # Per-provider parallelism.
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
