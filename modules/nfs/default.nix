{ config, lib, ... }:
with lib;
let
  shareType = types.submodule {
    options = {
      path = mkOption {
        type = types.str;
        description = "Mount point path";
      };
      device = mkOption {
        type = types.str;
        description = "NFS share path (without host prefix)";
      };
    };
  };
in
{
  options = {
    host = mkOption {
      type = types.str;
      default = "fileshare.local";
      description = "NFS server hostname";
    };
    ip = mkOption {
      type = types.str;
      default = "192.168.2.103";
      description = "NFS server IP address";
    };
    shares = mkOption {
      type = types.listOf shareType;
      default = [];
      description = "List of NFS shares to mount";
    };
    nfsShareOptions = mkOption {
      type = types.listOf types.str;
      default = [
        "nfsvers=4"
        "x-systemd.automount"
        "noauto"
      ];
      description = "Default NFS mount options";
    };
    port = mkOption {
      type = types.int;
      default = 2049;
      description = "NFS server TCP port";
    };
  };

  config = {
    networking.hosts."${config.ip}" = mkAfter [ config.host ];
    networking.firewall.allowedTCPPorts = mkAfter [ config.port ];

    fileSystems = listToAttrs (map (share: {
      name = share.path;
      value = {
        device = "${config.host}:${share.device}";
        fsType = "nfs";
        options = config.nfsShareOptions;
      };
    }) config.shares);

    systemd.tmpfiles.rules = map (share: "d '${share.path}' 0755 root root - -") config.shares;
  };
}
