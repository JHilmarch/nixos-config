{ pkgs }:
{
  ssh = import ./ssh.nix { inherit pkgs; };
  nugetMcpBuilder = import ./nuget-mcp-builder.nix;
}
