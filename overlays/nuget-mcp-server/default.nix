self: super: let
  buildNugetMcp = import ../../functions/nuget-mcp-builder.nix;
in {
  mcp-nuget = buildNugetMcp {
    pkgs = super;
    pname = "mcp-nuget";
    packageName = "NuGet.Mcp.Server";
    version = "1.0.0";
    sha256 = "sha256-W2y+jG2JQNN19fd8+TcfpMxvkA3bt3l8jHhwvkI7nVA=";
    dllName = "NuGet.Mcp.Server.dll";
    libDirName = "mcp-nuget";
    description = "NuGet MCP Server packaged from nuget.org .nupkg";
    homepage = "https://www.nuget.org/packages/NuGet.Mcp.Server";
  };
}
