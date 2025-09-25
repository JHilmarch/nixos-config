self: super: let
  lib = super.lib;
  version = "0.1.4-preview";
  src = super.fetchurl {
    url = "https://www.nuget.org/api/v2/package/NuGet.Mcp.Server/${version}";
    sha256 = "sha256-v2TaKFQYa+hUzSG6OXmJP5kq2gTmYdYVTnUBKunUvQE=";
  };
  dotnet = super.dotnetCorePackages.dotnet_10.sdk;
in {
  mcp-nuget = super.stdenvNoCC.mkDerivation {
    pname = "mcp-nuget";
    inherit version src;

    nativeBuildInputs = [super.unzip super.makeWrapper];

    unpackPhase = ''
      runHook preUnpack
      # .nupkg is a zip archive
      mkdir source
      unzip -q "$src" -d source
      runHook postUnpack
    '';

    installPhase = ''
      runHook preInstall
      mkdir -p $out/bin
      mkdir -p $out/lib/mcp-nuget
      cp -R source/* $out/lib/mcp-nuget/

      DLL=$(find "$out/lib/mcp-nuget" -type f -name 'NuGet.Mcp.Server.dll' | head -n1 || true)
      if [[ -z "${DLL:-}" ]]; then
        echo "NuGet.Mcp.Server.dll not found in package" >&2
        exit 1
      fi

      makeWrapper ${dotnet}/bin/dotnet $out/bin/mcp-nuget \
        --add-flags "$DLL"

      runHook postInstall
    '';

    meta = with lib; {
      description = "NuGet MCP Server packaged from nuget.org .nupkg";
      homepage = "https://www.nuget.org/packages/NuGet.Mcp.Server";
      license = licenses.mit;
      platforms = platforms.unix;
    };
  };
}
