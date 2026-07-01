{
  config,
  pkgs,
  lib,
  ...
}: {
  config = lib.mkIf config.programs.opencode.enable {
    # Weekly prune of audit sessions older than 180 days.
    systemd.user.services.opencode-audit-rotate = {
      Unit = {
        Description = "Prune old nono audit sessions for opencode (>180 days)";
        Documentation = "see: home-modules/opencode/nono-audit.md";
      };
      Service = {
        Type = "oneshot";
        ExecStart = "${lib.getExe pkgs.nono} audit cleanup --older-than 180 --silent";
      };
    };

    systemd.user.timers.opencode-audit-rotate = {
      Unit.Description = "Weekly prune of nono audit sessions for opencode";
      Timer = {
        OnCalendar = "weekly";
        Persistent = true;
      };
      Install.WantedBy = ["timers.target"];
    };
  };
}
