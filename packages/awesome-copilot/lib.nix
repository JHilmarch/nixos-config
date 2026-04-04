{
  lib,
  writeText,
  replaceVars,
  runtimeShell,
  dotnet,
  icu,
  src,
  patchScript,
}: let
  buildPhaseScript = ./build-phase.sh;
  installPhaseScript = ./install-phase.sh;
  wrapperScript = ./wrapper.sh;

  patchScriptFile = writeText "patch-mcp-logging.sh" (builtins.readFile patchScript);

  wrapper' = replaceVars wrapperScript {
    inherit dotnet icu;
    inherit runtimeShell;
  };

  buildPhase' = replaceVars buildPhaseScript {
    inherit dotnet patchScriptFile;
  };

  installPhase' = replaceVars installPhaseScript {
    wrapperScript = wrapper';
  };
in {
  inherit buildPhase' installPhase' wrapper';
}
