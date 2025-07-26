{ config, lib, pkgs, ... }:

{
  options = {
    services.systemdWakeOnLan = {
      enable = lib.mkEnableOption "Enable Wake-on-LAN systemd service";
      interface = lib.mkOption {
        type = lib.types.str;
        default = "enp6s0";
        description = "Network interface to enable Wake-on-LAN for";
      };
    };
  };

  config = lib.mkIf config.services.systemdWakeOnLan.enable {
    systemd.services.systemdWakeOnLan = {
      description = "Enable Wake-on-LAN with magic package";
      wantedBy = [ "multi-user.target" ];
      serviceConfig = {
        Type = "oneshot";
        ExecStart = "${pkgs.ethtool}/bin/ethtool -s ${config.services.systemdWakeOnLan.interface} wol g";
      };
    };
  };
}
