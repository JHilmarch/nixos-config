{
  lib,
  super,
  dotnet,
  icu,
  src,
  patchScript,
}: let
  buildPhaseScript = ./build-phase.sh;
  installPhaseScript = ./install-phase.sh;
  wrapperScript = ./wrapper.sh;

  patchScriptFile = super.writeText "patch-mcp-logging.sh" (builtins.readFile patchScript);

  wrapper' = super.replaceVars wrapperScript {
    inherit dotnet icu;
    runtimeShell = super.runtimeShell;
  };

  buildPhase' = super.replaceVars buildPhaseScript {
    inherit dotnet patchScriptFile;
  };

  installPhase' = super.replaceVars installPhaseScript {
    wrapperScript = wrapper';
  };
in {
  inherit buildPhase' installPhase' wrapper';
}
