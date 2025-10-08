self: super: let
  buildNugetMcp = import ../../functions/nuget-mcp-builder.nix;
in {
  azure-mcp-server = buildNugetMcp {
    pkgs = super;
    pname = "azure-mcp-server";
    packageName = "Azure.Mcp";
    version = "0.8.5";
    sha256 = "sha256-QzApwu1Y6l8nbxtsl+30DdDOhKzka8z+ICya2sRfNMM=";
    dllName = "Azure.Mcp.Server.dll";
    libDirName = "azure-mcp";
    description = "Azure MCP Server packaged from nuget.org Azure.Mcp";
    homepage = "https://www.nuget.org/packages/Azure.Mcp";
  };
}
