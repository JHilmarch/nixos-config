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
