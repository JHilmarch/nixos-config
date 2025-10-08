# Reusable builder for MCP servers distributed as NuGet .nupkg.
# Parameters:
# - pkgs: nixpkgs set (usually `super` inside overlays)
# - pname: resulting derivation name and wrapper binary name
# - packageName: name of the NuGet package on nuget.org
# - version: version string of the NuGet package
# - sha256: fixed-output hash for the .nupkg download
# - dllName: the main DLL to execute with dotnet
# - libDirName: directory name under $out/lib where contents are installed
# - description: meta.description
# - homepage: meta.homepage
{ pkgs
, pname
, packageName
, version
, sha256
, dllName
, libDirName
, description
, homepage
}:
let
  lib = pkgs.lib;
  dotnet = pkgs.dotnetCorePackages.dotnet_10.sdk;
  src = pkgs.fetchurl {
    url = "https://www.nuget.org/api/v2/package/${packageName}/${version}";
    inherit sha256;
  };
in
pkgs.stdenvNoCC.mkDerivation {
  inherit pname version src;

  nativeBuildInputs = [ pkgs.unzip pkgs.makeWrapper ];

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
    mkdir -p $out/lib/${libDirName}
    cp -R source/* $out/lib/${libDirName}/

    DLL=$(find "$out/lib/${libDirName}" -type f -name '${dllName}' | head -n1 || true)
    if [[ -z "${DLL:-}" ]]; then
      echo "${dllName} not found in package" >&2
      exit 1
    fi

    makeWrapper ${dotnet}/bin/dotnet $out/bin/${pname} \
      --add-flags "$DLL"

    runHook postInstall
  '';

  meta = with lib; {
    inherit homepage;
    description = description;
    license = licenses.mit;
    platforms = platforms.unix;
  };
}
