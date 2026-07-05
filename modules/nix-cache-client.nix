# Point every LAN host at the homelab binary cache (story #130, task #141).
#
# The LAN cache is prepended as the first substituter so day-to-day rebuilds
# pull from the network; the public caches remain as ordered fallbacks so a
# down/rebuilding cache never blocks a rebuild. The cache's signing public key
# is trusted so clients verify what they download.
#
# Single source of truth: imported once via templates/common.nix, so it reaches
# every real LAN host (orion, p51, and the homelab LXCs) without copy-paste.
#
# The cache host is guarded against pointing at itself — listing its own URL as
# a substituter would deadlock its first build before nix-serve is up.
{
  config,
  lib,
  ...
}: let
  cacheUrl = "https://cache.fileshare.se";
  cachePublicKey = "cache.nixos-homelab-1:Y9QcUiR8SVS6X5fToHddfIG0asjY6+4NXi1PeVx1XYU=";
  # The numtide binary cache is used flake-wide (see flake.nix nix.config); it
  # stays as an ordered public fallback after the LAN cache.
  numtideUrl = "https://cache.numtide.com";
  numtidePublicKey = "niks3.numtide.com-1:DTx8wZduET09hRmMtKdQDxNNthLQETkc/yaX7M4qK0g=";
  isCacheHost = config.networking.hostName == "cache";
in {
  nix.settings = {
    # LAN cache first (unless we ARE the cache), public caches after. The
    # built-in cache.nixos.org is appended by Nix as the final fallback.
    extra-substituters = lib.optional (!isCacheHost) cacheUrl ++ [numtideUrl];
    # Trust both the LAN cache and numtide keys everywhere, including on the
    # cache host itself so it can verify its own signed paths.
    extra-trusted-public-keys = [cachePublicKey numtidePublicKey];
  };
}
