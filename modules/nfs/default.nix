{
  config,
  lib,
  ...
}:
with lib; let
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
in {
  options = {
    nfs = {
      enable = mkOption {
        type = types.bool;
        default = false;
        description = "Enable this NFS fileshare submodule";
      };
      host = mkOption {
        type = types.str;
        description = "NFS server hostname";
      };
      ip = mkOption {
        type = types.str;
        description = "NFS server IP address";
      };
      shares = mkOption {
        type = types.listOf shareType;
        default = [];
        description = "List of NFS shares to mount";
      };
      shareOptions = mkOption {
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
  };

  config = {
    networking.hosts."${config.nfs.ip}" = mkAfter [config.nfs.host];
    networking.firewall.allowedTCPPorts = mkAfter [config.nfs.port];

    fileSystems = listToAttrs (map (share: {
        name = share.path;
        value = {
          device = "${config.nfs.host}:${share.device}";
          fsType = "nfs";
          options = config.nfs.shareOptions;
        };
      })
      config.nfs.shares);

    systemd.tmpfiles.rules = map (share: "d '${share.path}' 0755 root root - -") config.nfs.shares;
  };
}
