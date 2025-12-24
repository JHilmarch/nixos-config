self: super: let
  lib = super.lib;
  dotnet = super.dotnetCorePackages.dotnet_9.sdk;
  icu = super.icu;

  src = super.fetchFromGitHub {
    owner = "microsoft";
    repo = "mcp-dotnet-samples";
    rev = "6f0e66c81c5a6e48964ed006a645ad4e84e638fb";
    hash = "sha256-TrJ2Iuj3sUZsyq6B5qRaRAWnvkFTimrrZd3wlHqjGH4=";
  };

  phases = (import ./lib.nix) {
    inherit lib super dotnet icu src;
    patchScript = ./patch-mcp-logging.sh;
  };
in {
  awesome-copilot = super.buildDotnetModule rec {
    pname = "awesome-copilot";
    version = "1.0.0";

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
