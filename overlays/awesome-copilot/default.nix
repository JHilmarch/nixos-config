self: super: let
  lib = super.lib;
  dotnet = super.dotnetCorePackages.dotnet_9.sdk;
  icu = super.icu;

  src = super.fetchFromGitHub {
    owner = "microsoft";
    repo = "mcp-dotnet-samples";
    rev = "8b405cd0c54dbbbbcc61af21a63d2559b880fd73";
    hash = "sha256-haXZuSHRD6b4fpFRJE5FWDbDDjcqh/TAW/NHSEY4nYg=";
  };

  phases = (import ./lib.nix) {
    inherit lib super dotnet icu src;
    patchScript = ./patch-mcp-logging.sh;
  };
in {
  awesome-copilot = super.buildDotnetModule rec {
    pname = "awesome-copilot";
    version = "2026-02-13";

    inherit src;

    projectFile = "awesome-copilot/src/McpSamples.AwesomeCopilot.HybridApp/McpSamples.AwesomeCopilot.HybridApp.csproj";
    nugetDeps = ./deps.json;

    dotnet-sdk = dotnet;
    dotnet-runtime = super.dotnetCorePackages.dotnet_9.runtime;

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

    meta = with super.lib; {
      description = "Awesome Copilot MCP packaged via overlay with a .NET 9 wrapper";
      homepage = "https://github.com/microsoft/mcp-dotnet-samples/tree/main/awesome-copilot";
      license = licenses.mit;
      platforms = platforms.unix;
      maintainers = [];
    };
  };
}
