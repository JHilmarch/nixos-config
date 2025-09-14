# NixOS module enabling rootless Docker for local developer tooling.
# - Disables the rootful system daemon.
# - Enables rootless Docker and exports DOCKER_HOST to the user session.
# Intended for local workflows (e.g., Rider + GitHub MCP via Docker).
{
  config,
  lib,
  pkgs,
  ...
}: {
  virtualisation.docker = {
    enable = false;
    rootless = {
      enable = true;
      setSocketVariable = true;
    };
  };
}
