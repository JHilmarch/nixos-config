# Prefer the LAN binary cache on every host, with the public caches as ordered
# fallbacks. Substituters are tried in order, so the LAN cache is listed first
# and cache.nixos.org (Nix's built-in default) is appended last. The cache host
# is excluded from its own substituter list so it never substitutes from itself.
{
  config,
  lib,
  ...
}: let
  cacheUrl = "https://cache.fileshare.se";
  cachePublicKey = "cache.nixos-homelab-1:Y9QcUiR8SVS6X5fToHddfIG0asjY6+4NXi1PeVx1XYU=";
  numtideUrl = "https://cache.numtide.com";
  numtidePublicKey = "niks3.numtide.com-1:DTx8wZduET09hRmMtKdQDxNNthLQETkc/yaX7M4qK0g=";
  isCacheHost = config.networking.hostName == "cache";
in {
  nix.settings = {
    extra-substituters = lib.optional (!isCacheHost) cacheUrl ++ [numtideUrl];
    extra-trusted-public-keys = [cachePublicKey numtidePublicKey];
  };
}
