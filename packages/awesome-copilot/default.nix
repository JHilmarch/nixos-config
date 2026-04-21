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
    rev = "f22164817aff3a2fbc49a86453bee723e7f46838";
    hash = "sha256-Lyy6MR1c53tWWhnK+l6lMo/wkRnCioNUxxUkeSSgLX4=";
  };

  phases = import ./lib.nix {
    inherit lib writeText replaceVars runtimeShell dotnet icu src;
    patchScript = ./patch-mcp-logging.sh;
  };
in
  buildDotnetModule rec {
    pname = "awesome-copilot";
    version = "2026-04-21";

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
