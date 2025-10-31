{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.programs.xorgAllowRoot;
in {
  options.programs.xorgAllowRoot = {
    enable = lib.mkEnableOption "Allow local root to connect to the X server (xhost)";
    revokeOnStop = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Revoke on service stop (xhost -SI:localuser:root).";
    };
  };

  config = lib.mkIf cfg.enable {
    systemd.user.services.xhost-root = {
      Unit = {
        Description = "Allow root to connect to X server";
        After = ["graphical-session.target"];
      };
      Install = {WantedBy = ["graphical-session.target"];};
      Service = {
        Type = "oneshot";
        ExecStart = "${pkgs.xorg.xhost}/bin/xhost +SI:localuser:root";
        ExecStop = lib.mkIf cfg.revokeOnStop "${pkgs.xorg.xhost}/bin/xhost -SI:localuser:root";
        RemainAfterExit = true;
      };
    };
  };
}
