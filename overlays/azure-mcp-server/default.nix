self: super: let
  dotnet = super.dotnetCorePackages.dotnet_10.sdk;
  icu = super.icu;
  depsPath = ./deps.json;
  deps = builtins.fromJSON (builtins.readFile depsPath);
  lib = super.lib;

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
    azureEntries = lib.filter (p: p.name == "Azure.Mcp") deps;
  in
    if azureEntries != []
    then (lib.head azureEntries).version
    else "unknown";
in {
  azure-mcp-server =
    if deps == []
    then
      throw ''        azure-mcp-server: overlays/azure-mcp-server/deps.json is empty.
        Please generate it with:
          bash scripts/generate-nuget-deps.sh Azure.Mcp <Version> overlays/azure-mcp-server/deps.json''
    else
      super.stdenvNoCC.mkDerivation {
        pname = "azure-mcp-server";
        version = toolVersion;
        nativeBuildInputs = [super.makeWrapper];
        dontUnpack = true;
        installPhase = ''
          runHook preInstall
          mkdir -p $out/bin $out/nuget-source
          ${copyLines}
          makeWrapper ${dotnet}/bin/dotnet $out/bin/azure-mcp-server \
            --prefix LD_LIBRARY_PATH : ${icu}/lib \
            --set DOTNET_SYSTEM_GLOBALIZATION_INVARIANT 0 \
            --add-flags "dnx" \
            --add-flags "Azure.Mcp" \
            --add-flags "--source" \
            --add-flags "$out/nuget-source" \
            --add-flags "--ignore-failed-sources" \
            --add-flags "--" \
            --add-flags "azmcp" \
            --add-flags "server" \
            --add-flags "start"
          runHook postInstall
        '';
        meta = with super.lib; {
          description = "Azure MCP Server";
          homepage = "https://www.nuget.org/packages/Azure.Mcp";
          license = licenses.mit;
          platforms = platforms.unix;
        };
      };
}
