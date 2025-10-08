self: super: let
  lib = super.lib;
  version = "0.8.5";
  src = super.fetchurl {
    url = "https://www.nuget.org/api/v2/package/Azure.Mcp/${version}";
    sha256 = "sha256-QzApwu1Y6l8nbxtsl+30DdDOhKzka8z+ICya2sRfNMM=";
  };
  dotnet = super.dotnetCorePackages.dotnet_10.sdk;
in {
  azure-mcp-server = super.stdenvNoCC.mkDerivation {
    pname = "azure-mcp-server";
    inherit version src;

    nativeBuildInputs = [ super.unzip super.makeWrapper ];

    unpackPhase = ''
      runHook preUnpack
      mkdir source
      # .nupkg is a zip archive
      unzip -q "$src" -d source
      runHook postUnpack
    '';

    installPhase = ''
      runHook preInstall
      mkdir -p $out/bin
      mkdir -p $out/lib/azure-mcp
      cp -R source/* $out/lib/azure-mcp/

      DLL=$(find "$out/lib/azure-mcp" -type f -name 'Azure.Mcp.Server.dll' | head -n1 || true)
      if [[ -z "${DLL:-}" ]]; then
        echo "Azure.Mcp.Server.dll not found in package" >&2
        exit 1
      fi

      makeWrapper ${dotnet}/bin/dotnet $out/bin/azure-mcp-server \
        --add-flags "$DLL"

      runHook postInstall
    '';

    meta = with lib; {
      description = "Azure MCP Server packaged from nuget.org Azure.Mcp";
      homepage = "https://www.nuget.org/packages/Azure.Mcp";
      license = licenses.mit;
      platforms = platforms.unix;
    };
  };
}
