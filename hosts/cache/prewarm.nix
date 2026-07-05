# Twice-daily pre-warm of the LAN binary cache (story #130, task #142).
#
# A oneshot systemd service, fired by a timer at 06:00 and 18:00, realises the
# system closure of every NixOS host in this flake into the cache's local store
# and signs it with the cache key, so nix-serve-ng (which serves the local
# /nix/store) offers every host's build to the LAN.
#
# The host list is DERIVED from self.nixosConfigurations at build time — new
# hosts are picked up automatically on the next nixos-rebuild of this host. The
# flake source is self.outPath (the exact revision this host was built from), so
# closures are byte-identical and no network/credentials are needed to evaluate.
{
  config,
  pkgs,
  lib,
  self,
  ...
}: let
  # Hosts whose closures we do NOT pre-warm:
  #   cache   — this host; building its own closure into its own store is a no-op
  #             and would risk substituting from itself (guarded in #141 anyway).
  #   iso     — installer image, not a LAN client.
  #   wsl-cab — WSL dev env, not a homelab LAN client.
  excluded = ["nixos-cache" "iso" "wsl-cab"];

  # Derived from the flake, not hardcoded: every nixosConfiguration except the
  # excluded set. New hosts flow in automatically on the next rebuild.
  prewarmHosts =
    lib.filter (name: !(lib.elem name excluded))
    (lib.attrNames self.nixosConfigurations);

  flakeRef = self.outPath;
  keyFile = config.sops.secrets."nix-cache-priv-key".path;

  prewarmScript = pkgs.writeShellApplication {
    name = "cache-prewarm";
    runtimeInputs = [pkgs.nix pkgs.coreutils];
    text = ''
      set -uo pipefail

      flake="${flakeRef}"
      key_file="${keyFile}"
      hosts=(${lib.concatStringsSep " " prewarmHosts})

      failures=0
      for host in "''${hosts[@]}"; do
        echo "prewarm: realising toplevel for $host"
        attr="$flake#nixosConfigurations.$host.config.system.build.toplevel"

        # Build into the local store. On failure, log and keep going so one
        # broken host never aborts the whole run.
        if ! out=$(nix build --no-link --print-out-paths "$attr" 2>&1); then
          echo "prewarm: FAILED to build $host — skipping" >&2
          printf '%s\n' "$out" >&2
          failures=$((failures + 1))
          continue
        fi

        # Sign the whole closure with the cache key so LAN clients trust it.
        if ! nix store sign --recursive --key-file "$key_file" "$out"; then
          echo "prewarm: FAILED to sign closure for $host ($out)" >&2
          failures=$((failures + 1))
          continue
        fi

        echo "prewarm: signed $host → $out"
      done

      if [ "$failures" -gt 0 ]; then
        echo "prewarm: completed with $failures host failure(s)" >&2
        exit 1
      fi
      echo "prewarm: all hosts realised and signed"
    '';
  };
in {
  systemd.services.cache-prewarm = {
    description = "Pre-warm the LAN binary cache with every host's system closure";
    # nix-serve serves the local store; the signing key must be materialised.
    after = ["network-online.target" "sops-nix.service"];
    wants = ["network-online.target"];
    serviceConfig = {
      Type = "oneshot";
      ExecStart = lib.getExe prewarmScript;
      # Pre-warm is background maintenance — never starve the box.
      Nice = 19;
      IOSchedulingClass = "idle";
      # A full flake eval + several closure builds can be slow on an LXC.
      TimeoutStartSec = "3h";
    };
  };

  systemd.timers.cache-prewarm = {
    description = "Twice-daily pre-warm of the LAN binary cache";
    wantedBy = ["timers.target"];
    timerConfig = {
      OnCalendar = "*-*-* 06,18:00:00";
      Persistent = true; # catch up a missed run (e.g. host was off)
    };
  };
}
