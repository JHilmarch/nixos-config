{
  config,
  lib,
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

  glm = "zai-coding-plan/glm-5.1";
  glmFlash = "zai-coding-plan/glm-5-turbo";
  glmVision = "zai-coding-plan/glm-5v-turbo";
  gpt55 = "openai/gpt-5.5";
  gpt54 = "openai/gpt-5.4";

  globalPromptAppend = lib.strings.removeSuffix "\n" (builtins.readFile "${self}/ai/global-prompt-append.md");

  agentsBase = {
    sisyphus.model = glm;
    sisyphus-junior.model = glm;
    prometheus.model = glm;
    atlas.model = glm;
    hephaestus = {
      model = gpt54;
      variant = "medium";
    };
    oracle = {
      model = gpt55;
      variant = "high";
    };
    momus = {
      model = gpt55;
      variant = "high";
    };
    metis = {
      model = gpt55;
      variant = "medium";
    };
    librarian.model = glmFlash;
    explore.model = glmFlash;
    multimodal-looker.model = glmVision;
  };

  agentsWithPromptAppend = lib.mapAttrs (_name: cfg:
    if lib.hasPrefix "zai-coding-plan/" cfg.model
    then cfg // {prompt_append = globalPromptAppend;}
    else cfg)
  agentsBase;
in
  lib.mkIf config.programs.opencode.enable {
    programs.opencode.settings.plugin = ["oh-my-openagent"];

    home.file =
      skillFiles
      // {
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
          disabled_skills = ["git-master"];
          ralph_loop = {
            enabled = true;
            default_max_iterations = 25;
          };
          agents = agentsWithPromptAppend;
          categories = {
            ultrabrain = {
              model = gpt55;
              variant = "xhigh";
            };
            deep = {
              model = gpt54;
              variant = "high";
            };
            unspecified-high = {
              model = gpt54;
              variant = "high";
            };
            quick.model = glmFlash;
            writing.model = glmFlash;
            visual-engineering.model = glmVision;
            artistry.model = glm;
            unspecified-low.model = glm;
          };
        };
      };
  }
