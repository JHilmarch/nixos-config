{
  lib,
  stdenvNoCC,
  fetchurl,
  unzip,
  dotnetCorePackages,
  icu,
  writeText,
  replaceVars,
  runtimeShell,
}: let
  dotnet = dotnetCorePackages.dotnet_10.sdk;
  depsPath = ./deps.json;
  deps = builtins.fromJSON (builtins.readFile depsPath);

  # Find the linux-x64 RID package (contains all DLLs for native execution)
  ridPkg = builtins.head (
    lib.filter (p: lib.hasInfix "linux-x64" p.name) deps
  );

  fetchedRidPkg = fetchurl {
    url = "https://www.nuget.org/api/v2/package/${ridPkg.name}/${ridPkg.version}";
    sha256 = ridPkg.sha256;
    name = "${ridPkg.name}.${ridPkg.version}.nupkg";
  };

  # Determine tool version from deps when present
  toolVersion = let
    entries = lib.filter (p: lib.toLower p.name == "nuget.mcp.server") deps;
  in
    if entries != []
    then (lib.head entries).version
    else "unknown";

  phases = import ./lib.nix {
    inherit lib writeText replaceVars runtimeShell dotnet icu fetchedRidPkg;
  };
in
  if deps == []
  then
    throw ''      mcp-nuget: packages/nuget-mcp-server/deps.json is empty.
      Please generate it with:
        bash tools/update-packages/scripts/generate-nuget-deps.sh NuGet.Mcp.Server <Version> packages/nuget-mcp-server/deps.json''
  else
    stdenvNoCC.mkDerivation {
      pname = "mcp-nuget";
      version = toolVersion;
      nativeBuildInputs = [unzip];
      dontUnpack = true;
      installPhase = ''
        source ${phases.installPhase'}
        installPhase
      '';
      passthru = {
        inherit (phases) installPhase' wrapper';
      };
      meta = with lib; {
        description = "NuGet MCP Server";
        homepage = "https://www.nuget.org/packages/NuGet.Mcp.Server";
        license = licenses.mit;
        platforms = platforms.unix;
      };
    }
