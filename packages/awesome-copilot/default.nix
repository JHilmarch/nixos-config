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
    rev = "7dc89b8b0ebee5dc9307c12d7442ca5ad699c30a";
    hash = "sha256-h/MN8OUHJ5HbMh0nUiPxCG38HMzXTtp7gHr3YkIGKdo=";
  };

  phases = import ./lib.nix {
    inherit lib writeText replaceVars runtimeShell dotnet icu src;
    patchScript = ./patch-mcp-logging.sh;
  };
in
  buildDotnetModule rec {
    pname = "awesome-copilot";
    version = "2026-04-01";

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
