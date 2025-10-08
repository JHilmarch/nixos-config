self: super:
let
  buildNugetMcp = import ../../functions/nuget-mcp-builder.nix;
in {
  mcp-nuget = buildNugetMcp {
    pkgs = super;
    pname = "mcp-nuget";
    packageName = "NuGet.Mcp.Server";
    version = "0.1.4-preview";
    sha256 = "sha256-v2TaKFQYa+hUzSG6OXmJP5kq2gTmYdYVTnUBKunUvQE=";
    dllName = "NuGet.Mcp.Server.dll";
    libDirName = "mcp-nuget";
    description = "NuGet MCP Server packaged from nuget.org .nupkg";
    homepage = "https://www.nuget.org/packages/NuGet.Mcp.Server";
  };
}
