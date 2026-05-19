{
  lib,
  fetchFromGitHub,
  buildDotnetModule,
  dotnetCorePackages,
  icu,
  writeText,
  replaceVars,
  runtimeShell,
}: let
  dotnet = dotnetCorePackages.dotnet_10.sdk;

  src = fetchFromGitHub {
    owner = "microsoft";
    repo = "mcp-dotnet-samples";
    rev = "f5796a10297c078d523a143f1ef3868b4dc90f48";
    hash = "sha256-Ux4OdtV2QwKOb4lLeVFrYeU8MzWjGpVKN0pG+1326xo=";
  };

  phases = import ./lib.nix {
    inherit lib writeText replaceVars runtimeShell dotnet icu src;
    patchScript = ./patch-mcp-logging.sh;
  };
in
  buildDotnetModule rec {
    pname = "awesome-copilot";
    version = "2026-05-01";

    inherit src;

    projectFile = "awesome-copilot/src/McpSamples.AwesomeCopilot.HybridApp/McpSamples.AwesomeCopilot.HybridApp.csproj";
    nugetDeps = ./deps.json;

    dotnet-sdk = dotnet;
    dotnet-runtime = dotnetCorePackages.dotnet_10.runtime;

    runtimeDeps = [icu];

    buildPhase = ''
      source ${phases.buildPhase'}
      buildPhase false
    '';

    installPhase = ''
      source ${phases.installPhase'}
      installPhase
    '';

    passthru = {
      inherit (phases) buildPhase' installPhase' wrapper';
    };

    meta = with lib; {
      description = "Awesome Copilot MCP packaged with a .NET 10 wrapper";
      homepage = "https://github.com/microsoft/mcp-dotnet-samples/tree/main/awesome-copilot";
      license = licenses.mit;
      platforms = platforms.unix;
      maintainers = [];
    };
  }
