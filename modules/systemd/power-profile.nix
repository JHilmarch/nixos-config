{
  config,
  lib,
  pkgs,
  ...
}: {
  options = {
    services.systemdPowerProfile = {
      enable = lib.mkEnableOption "Set power profile to performance on boot";
    };
  };

  config = lib.mkIf config.services.systemdPowerProfile.enable {
    systemd.services.systemdPowerProfile = {
      description = "Set power profile to performance";
      wantedBy = ["multi-user.target"];
      after = ["power-profiles-daemon.service"];
      wants = ["power-profiles-daemon.service"];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = "yes";
      };
      script = ''
        ${pkgs.power-profiles-daemon}/bin/powerprofilesctl set performance
      '';
    };
  };
}
