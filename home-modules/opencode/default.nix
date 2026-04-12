{
  config,
  pkgs,
  lib,
  inputs,
  ...
}: {
  options.modules.opencode = with lib; {
    preSetupScripts = mkOption {
      type = types.listOf types.str;
      default = [];
      description = "Shell scripts to source before running OpenCode";
    };

    runtimeInputs = mkOption {
      type = types.listOf types.package;
      default = [];
      description = "Additional packages to add to PATH";
    };
  };

  config = let
    cfg = config.modules.opencode;
    opencode-pkg =
      inputs.llm-agents.packages.${pkgs.stdenv.hostPlatform.system}.opencode;

    opencode-wrapper = pkgs.writeShellApplication {
      name = "opencode";
      runtimeInputs = [opencode-pkg] ++ cfg.runtimeInputs;
      checkPhase = "true";
      text = ''
        ${lib.concatMapStrings (script: ''
            . ${script}
          '')
          cfg.preSetupScripts}

        exec ${lib.getExe opencode-pkg} "$@"
      '';
    };
  in
    lib.mkIf config.programs.opencode.enable {
      home.packages = [opencode-wrapper];
    };
}
