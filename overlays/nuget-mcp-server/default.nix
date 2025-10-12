self: super: let
  dotnet = super.dotnetCorePackages.dotnet_10.sdk;
  icu = super.icu;
  lib = super.lib;
  depsPath = ./deps.json;
  deps = builtins.fromJSON (builtins.readFile depsPath);

  # Fetch all pinned nuget packages defined in deps.json
  fetched =
    lib.map (
      p:
        super.fetchurl {
          url = "https://www.nuget.org/api/v2/package/${p.name}/${p.version}";
          sha256 = p.sha256;
          name = "${p.name}.${p.version}.nupkg";
        }
    )
    deps;

  # Build copy commands to populate a local nuget source folder
  nupkgNames = lib.map (p: "${p.name}.${p.version}.nupkg") deps;
  nupkgPairs = lib.lists.zipLists fetched nupkgNames;
  copyLines =
    lib.concatMapStrings (pair: ''
      cp -v ${pair.fst} "$out/nuget-source/${pair.snd}"
    '')
    nupkgPairs;

  # Determine tool version from deps when present
  toolVersion = let
    entries = lib.filter (p: lib.toLower p.name == "nuget.mcp.server") deps;
  in
    if entries != []
    then (lib.head entries).version
    else "unknown";
in {
  mcp-nuget =
    if deps == []
    then
      throw ''        mcp-nuget: overlays/nuget-mcp-server/deps.json is empty.
        Please generate it with:
          bash scripts/generate-nuget-deps.sh NuGet.Mcp.Server <Version> overlays/nuget-mcp-server/deps.json''
    else
      super.stdenvNoCC.mkDerivation {
        pname = "mcp-nuget";
        version = toolVersion;
        nativeBuildInputs = [super.makeWrapper];
        dontUnpack = true;
        installPhase = ''
          runHook preInstall
          mkdir -p $out/bin $out/nuget-source
          ${copyLines}
          makeWrapper ${dotnet}/bin/dotnet $out/bin/mcp-nuget \
            --prefix LD_LIBRARY_PATH : ${icu}/lib \
            --set DOTNET_SYSTEM_GLOBALIZATION_INVARIANT 0 \
            --add-flags "dnx" \
            --add-flags "NuGet.Mcp.Server" \
            --add-flags "--source" \
            --add-flags "file://$out/nuget-source" \
            --add-flags "--ignore-failed-sources" \
            --add-flags "--yes" \
            --add-flags "--" \
            --add-flags "mcp-nuget" \
            --add-flags "server" \
            --add-flags "start"
          runHook postInstall
        '';
        meta = with super.lib; {
          description = "NuGet MCP Server";
          homepage = "https://www.nuget.org/packages/NuGet.Mcp.Server";
          license = licenses.mit;
          platforms = platforms.unix;
        };
      };
}
