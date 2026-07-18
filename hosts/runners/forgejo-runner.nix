# Forgejo Actions runner executing CI jobs host-natively (":host" label,
# no container runtime): jobs run directly on this host and get its nix
# daemon plus the LAN binary cache substituters.
#
# Registers against the Forgejo instance on forge through the
# edge-terminated public URL. The registration tokenFile is an environment
# file (TOKEN=<value>) as required by the gitea-actions-runner module.
#
# The sbomnix suite comes from this flake's own outputs: the sbomnix
# package provides the sbomnix, vulnxscan and nix_outdated binaries;
# ghafscan provides ghafscan. vulnxscan reads NVD_API_KEY from the
# environment, injected into the daemon (and thereby host-executed jobs)
# via the extra systemd EnvironmentFile below. The same mechanism
# surfaces FORGEJO_PR_TOKEN to the scheduled flake-update workflow
# (`.forgejo/workflows/flake-update.yaml`), which uses it to push its
# bump branch and open the PR.
{
  config,
  pkgs,
  lib,
  self,
  ...
}: let
  scanTools = [
    self.packages.${pkgs.stdenv.hostPlatform.system}.sbomnix
    self.packages.${pkgs.stdenv.hostPlatform.system}.ghafscan
  ];
  runnerTools = with pkgs; [
    bash
    coreutils
    git
    nix
    gnused
    gnugrep
    gawk
    curl
    jq
    gnutar
    gzip
    nodejs
  ];
in {
  services.gitea-actions-runner = {
    package = pkgs.forgejo-runner;

    instances.${config.networking.hostName} = {
      enable = true;
      name = config.networking.hostName;
      url = "https://forge.fileshare.se/";
      tokenFile = config.sops.secrets."forgejo-runner-token".path;
      labels = ["nixos-x86_64:host"];
      hostPackages = runnerTools ++ scanTools;
    };
  };

  # The module already sets EnvironmentFile to the tokenFile as a plain
  # string; a list is required here so both definitions merge. Both
  # files are sourced into the daemon's env and thereby inherited by
  # every host-executed workflow step: NVD_API_KEY for vulnxscan, and
  # FORGEJO_PR_TOKEN for the scheduled flake-update workflow.
  systemd.services."gitea-runner-${config.networking.hostName}".serviceConfig.EnvironmentFile = [
    config.sops.secrets."nvd-api-key".path
    config.sops.secrets."forgejo-pr-token".path
  ];
}
