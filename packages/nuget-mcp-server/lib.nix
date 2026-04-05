{
  lib,
  writeText,
  replaceVars,
  runtimeShell,
  dotnet,
  icu,
  fetchedRidPkg,
}: let
  installPhaseScript = ./install-phase.sh;
  wrapperScript = ./wrapper.sh;

  wrapper' = replaceVars wrapperScript {
    inherit dotnet icu;
    inherit runtimeShell;
  };

  installPhase' = replaceVars installPhaseScript {
    inherit fetchedRidPkg;
    wrapperScript = wrapper';
  };
in {
  inherit installPhase' wrapper';
}
