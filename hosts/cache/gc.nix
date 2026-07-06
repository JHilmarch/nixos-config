# Monthly age-based garbage collection of the cache store, via the built-in
# `nix.gc` module (systemd `nix-gc` service + timer). This is a proactive sweep
# that complements the reactive min-free/max-free GC in configuration.nix:
# min/max-free only kicks in under disk pressure, while this timer enforces a
# steady 30-day retention regardless of free space. It also acts as a safety
# net once the store moves to larger HDDs (#148), where disk pressure alone
# would let stale closures accumulate for a long time.
#
# --delete-older-than 30d (never bare -d) keeps the last month of closures, so
# a recent rollback on any LAN host still resolves from this cache.
#
# The timer fires at 04:00 on the 1st of each month, deliberately clear of the
# pre-warm slots (06:00/18:00 daily, see prewarm.nix) so GC and pre-warm never
# run at the same time. The serviceConfig override nices the run and puts it in
# the idle IO class so a large sweep never starves the box — the built-in
# `nix.gc` module only sets `Type = "oneshot"`, so we layer that on here.
{...}: {
  nix.gc = {
    automatic = true;
    dates = "*-*-01 04:00:00";
    options = "--delete-older-than 30d";
    persistent = true;
  };

  systemd.services.nix-gc.serviceConfig = {
    Nice = 19;
    IOSchedulingClass = "idle";
  };
}
