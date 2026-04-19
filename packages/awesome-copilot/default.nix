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
    rev = "bbf7d48cce2049bf410e41c1af8f8dd6dc865ca7";
    hash = "sha256-imqxULHMdp5OclHxHkAB1lqz73iZcn1HjVkxNBjA1lE=";
  };

  phases = import ./lib.nix {
    inherit lib writeText replaceVars runtimeShell dotnet icu src;
    patchScript = ./patch-mcp-logging.sh;
  };
in
  buildDotnetModule rec {
    pname = "awesome-copilot";
    version = "2026-04-17";

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
