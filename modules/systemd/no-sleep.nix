{ config, lib, ... }:

{
  options = {
    services.systemdNoSleep.enable = lib.mkEnableOption "Disable all system sleep/hibernate modes";
  };

  config = lib.mkIf config.services.systemdNoSleep.enable {
    systemd.sleep.extraConfig = ''
      AllowSuspend=no
      AllowHibernation=no
      AllowHybridSleep=no
      AllowSuspendThenHibernate=no
    '';
  };
}
