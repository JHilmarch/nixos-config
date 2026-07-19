{
  config,
  lib,
  pkgs,
  inputs,
  ...
}: let
  cfg = config.security.overrides;
  inherit (pkgs.stdenv.hostPlatform) system;
  unstable = import inputs.nixpkgs-unstable {
    inherit system;
    config = pkgs.config;
  };
in {
  options.security.overrides = {
    enable = lib.mkEnableOption (lib.mdDoc ''
      Package overrides from nixpkgs-unstable to close CVEs not yet backported
      to the stable channel'');

    aggressive = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = lib.mdDoc ''
        Also override packages whose unstable version is a major bump. May
        trigger mass rebuilds and consumer breakage.'';
    };
  };

  config = lib.mkIf cfg.enable {
    nixpkgs.overlays = [
      (_final: _prev: {
        vim = unstable.vim;
        fzf = unstable.fzf;
        sqlite = unstable.sqlite;
        libmicrohttpd = unstable.libmicrohttpd;
        libcap = unstable.libcap;
        dash = unstable.dash;
      })

      (lib.mkIf cfg.aggressive (_final: _prev: {
        giflib = unstable.giflib;
        graphite2 = unstable.graphite2;
      }))
    ];
  };
}
