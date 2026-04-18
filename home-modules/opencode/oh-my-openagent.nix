{
  config,
  lib,
  ...
}: let
  glm = "anthropic/glm-5.1";
  glmFlash = "anthropic/glm-5-turbo";
in
  lib.mkIf config.programs.opencode.enable {
    programs.opencode.settings.plugin = ["oh-my-openagent"];

    home.file.".config/opencode/oh-my-openagent.json".text = builtins.toJSON {
      "$schema" = "https://raw.githubusercontent.com/code-yeongyu/oh-my-openagent/master/assets/oh-my-openagent.schema.json";
      google_auth = false;
      ralph_loop = {
        enabled = true;
        default_max_iterations = 25;
      };
      agents = {
        sisyphus.model = glm;
        sisyphus-junior.model = glm;
        hephaestus = {
          model = glm;
          allow_non_gpt_model = true;
        };
        oracle.model = glm;
        librarian.model = glm;
        explore.model = glmFlash;
        prometheus.model = glm;
      };
      categories = {
        quick.model = glm;
        deep.model = glm;
        writing.model = glm;
        visual-engineering.model = glm;
        ultrabrain.model = glm;
      };
    };
  }
