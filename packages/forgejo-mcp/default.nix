# Wrapper around the upstream forgejo-mcp (from nixpkgs-unstable) that injects
# the forgejo PAT from /run/secrets/forgejo-pat. Follows the same pattern as
# packages/github-mcp-server/base.nix.
#
# The upstream binary is passed as `forgejo-mcp-bin` (from flake.nix
# mkPackages, which sources it from nixpkgs-unstable) to avoid a naming
# collision with this wrapper's own binary name.
{
  lib,
  writeShellApplication,
  findutils,
  forgejo-mcp-bin,
}:
writeShellApplication {
  name = "forgejo-mcp";

  runtimeInputs = [findutils];

  text = ''
    FORGEJO_ACCESS_TOKEN="$(xargs </run/secrets/forgejo-pat)"
    export FORGEJO_ACCESS_TOKEN
    exec ${lib.getExe forgejo-mcp-bin} --transport stdio --url https://forge.fileshare.se
  '';

  meta = {
    description = "Forgejo MCP server authenticated via forgejo-pat secret";
    platforms = lib.platforms.all;
  };
}
