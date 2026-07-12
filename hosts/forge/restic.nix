# Daily restic backup of Forgejo + Postgres state to the Synology NAS.
#
# The live Postgres data dir cannot be file-copied consistently, so
# backupPrepareCommand first produces a consistent `forgejo dump` archive
# (repos + DB + config) plus a plain-SQL pg_dump into the staging dir, and
# restic then snapshots that dir into an encrypted, deduplicated, auto-pruned
# repository on the NAS (NFS automount). Uncompressed dump formats are chosen
# deliberately: restic's own chunking/compression dedups them across days.
{
  config,
  lib,
  pkgs,
  self,
  ...
}: {
  imports = [
    "${self}/modules/nfs/default.nix"
  ];

  nfs = {
    enable = true;
    host = "fileshare.local";
    ip = "192.168.2.103";
    shares = [
      {
        path = "/mnt/FILESHARE_FORGE_BACKUP";
        device = "/volume2/forge-backup";
      }
    ];
  };

  services.restic.backups.forge = {
    initialize = true;
    repository = "/mnt/FILESHARE_FORGE_BACKUP/restic";
    passwordFile = config.sops.secrets."restic-forge-password".path;
    paths = ["/var/lib/forgejo-backup"];

    backupPrepareCommand = let
      forgejo = config.services.forgejo;
      stagingDir = "/var/lib/forgejo-backup";
      # services.postgresql.package only has a value once T2 enables postgres.
      postgresqlPackage =
        if config.services.postgresql.enable
        then config.services.postgresql.package
        else pkgs.postgresql;
    in ''
      #!${pkgs.runtimeShell}
      set -euo pipefail

      ${pkgs.coreutils}/bin/rm -rf ${stagingDir}
      ${pkgs.coreutils}/bin/install -d -m 0750 -o ${forgejo.user} -g ${forgejo.group} ${stagingDir}

      ${pkgs.util-linux}/bin/runuser -u ${forgejo.user} -g ${forgejo.group} -- \
        ${pkgs.coreutils}/bin/env \
        USER=${forgejo.user} \
        HOME=${forgejo.stateDir} \
        FORGEJO_WORK_DIR=${forgejo.stateDir} \
        FORGEJO_CUSTOM=${forgejo.customDir} \
        ${lib.getExe forgejo.package} dump --type tar --file ${stagingDir}/forgejo-dump.tar

      ${pkgs.util-linux}/bin/runuser -u postgres -- \
        ${postgresqlPackage}/bin/pg_dump --format=plain ${forgejo.database.name} \
        > ${stagingDir}/forgejo-db.sql
    '';

    timerConfig = {
      OnCalendar = "05:30";
      Persistent = true;
    };

    pruneOpts = [
      "--keep-daily 7"
      "--keep-weekly 4"
      "--keep-monthly 6"
    ];
  };

  systemd.services.restic-backups-forge = {
    requires = ["mnt-FILESHARE_FORGE_BACKUP.automount"];
    after = ["mnt-FILESHARE_FORGE_BACKUP.automount"];
  };
}
