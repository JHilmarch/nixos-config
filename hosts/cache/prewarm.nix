# Twice-daily pre-warm of the LAN binary cache. A oneshot service realises the
# system closure of every host in this flake into the local store and signs it
# with the cache key, so nix-serve-ng (which serves the local store) offers each
# host's build to the LAN.
#
# The host list is derived from self.nixosConfigurations at build time, so new
# hosts are picked up on the next rebuild. Closures are built from self.outPath,
# the exact revision this host runs, so no network or credentials are needed.
#
# Excluded hosts:
#   nixos-cache — this host; it need not (and must not) substitute from itself.
#   iso         — installer image, not a LAN client.
#   wsl-cab     — WSL dev env, not a homelab LAN client.
#
# The service is niced and IO-idle so pre-warm never starves the box, and a
# single host that fails to build or sign is logged and skipped, not fatal.
{
  config,
  pkgs,
  lib,
  self,
  ...
}: let
  excluded = ["nixos-cache" "iso" "wsl-cab"];

  prewarmHosts =
    lib.filter (name: !(lib.elem name excluded))
    (lib.attrNames self.nixosConfigurations);

  prewarmScript = pkgs.writeShellApplication {
    name = "cache-prewarm";
    runtimeInputs = [pkgs.nix pkgs.coreutils];
    text = ''
      flake="${self.outPath}"
      key_file="${config.sops.secrets."nix-cache-priv-key".path}"
      hosts=(${lib.concatStringsSep " " prewarmHosts})

      ${builtins.readFile ./prewarm.sh}
    '';
  };
in {
  systemd.services.cache-prewarm = {
    description = "Pre-warm the LAN binary cache with every host's system closure";
    after = ["network-online.target" "sops-nix.service"];
    wants = ["network-online.target"];
    serviceConfig = {
      Type = "oneshot";
      ExecStart = lib.getExe prewarmScript;
      Nice = 19;
      IOSchedulingClass = "idle";
      TimeoutStartSec = "3h";
    };
  };

  systemd.timers.cache-prewarm = {
    description = "Twice-daily pre-warm of the LAN binary cache";
    wantedBy = ["timers.target"];
    timerConfig = {
      OnCalendar = "*-*-* 06,18:00:00";
      Persistent = true;
    };
  };
}
