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
# ghafscan provides ghafscan.
#
# Secrets are surfaced to host-executed jobs through the extra systemd
# EnvironmentFile below, each stored as a KEY=value env file:
#   NVD_API_KEY         read by vulnxscan (wrapped by ghafscan)
#   FORGEJO_PR_TOKEN    flake-update workflow (push branch + open PR)
#   FORGEJO_ISSUE_TOKEN daily-scanners workflow (open/close issues)
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

  # A list merges with the module's own tokenFile EnvironmentFile string.
  systemd.services."gitea-runner-${config.networking.hostName}".serviceConfig.EnvironmentFile = [
    config.sops.secrets."nvd-api-key".path
    config.sops.secrets."forgejo-pr-token".path
    config.sops.secrets."forgejo-issue-token".path
  ];
}
